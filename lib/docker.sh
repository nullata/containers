#!/usr/bin/env bash
# Copyright (c) 2025 NullSCA (nullata)
# Licensed under the Elastic License 2.0
# See LICENSE-SCRIPTS for details

# strict mode
# set -euo pipefail

function dockerActive {
    docker info >/dev/null 2>&1
}

function validateDockerProfile {
    local composeFile="$1"
    local profile="$2"
    local profiles=$(getDockerComposeProfiles "${composeFile}")
    if [[ -z "${profiles}" ]];then
        logError "Could not retrieve docker compose profiles from ${composeFile}"
    fi

    for p in ${profiles}; do
        if [[ $p == "${profile}" ]]; then
            return 0
        fi
    done

    return 1
}

function getDockerComposeProfiles {
    local composeFile="$1"
    yq -r '.services[]?.profiles[]' "${composeFile}" | uniq
}

function getComposeStatus {
    local composeFile="$1"
    local profile="$2"
    local cmdOut=$(docker compose --profile "${profile}" -f "${composeFile}" ps -a)
    logMessage "Status for ${profile} profile:
${cmdOut}"
}

function getComposeLogs {
    local composeFile="$1"
    local profile="$2"
    local cmdOut=$(docker compose --profile "${profile}" -f "${composeFile}" logs)
    logMessage "Showing logs for ${profile} profile...
${cmdOut}"
}

function buildContainerImage {
    local composeFile="$1"
    local targetDir=$(dirname "${composeFile}")
    # save the working dir
    local workDir=${PWD}
    cd "${targetDir}" || logError "Unable to navigate to image directory"

    logMessage "Initializing build procedure for ${targetDir}/Dockerfile"

    local appVersion=$(basename "${targetDir}")
    local appName=$(basename $(echo ${targetDir} | awk -F "${appVersion}" '{print $1}'))

    # read component versions from master VERSION file
    local masterVersionFile="${targetDir}/../VERSION"
    local buildArgs=""

    if [[ -f "${masterVersionFile}" ]]; then
        local components=$(jq -r '.components[]? | "--label \(.name).version=\(.latest_version)"' "${masterVersionFile}")
        buildArgs="${components}"
    fi

    logMessage "Building ${targetDir}/Dockerfile ..."
    docker build --no-cache -t nullata/${appName}:${appVersion} \
        ${buildArgs} \
        .

    if [[ $? -eq 0 ]]; then
        logMessage "Build completed successfully"

        local today=$(date +%Y-%m-%d)
        updateJsonProperty "build_date" "${today}"
    else
        logError "Build failed"
    fi
    cd ${workDir}
}

function startTestStack {
    local composeFile="$1"
    local profile="$2"
    local targetDir=$(dirname "${composeFile}")

    if [[ -x "${targetDir}/setup.sh" ]];then
        logWarning "Running pre-setup script..."
        "${targetDir}/setup.sh" init ${profile}
    else
        logWarning "Pre-setup script is missing or could not be found"
    fi

    local appVersion=$(basename "${targetDir}")
    local appName=$(basename $(echo ${targetDir} | awk -F "${appVersion}" '{print $1}'))
    export VERSION=${appVersion}

    logMessage "Starting ${profile}@${VERSION} profile..."
    docker compose --profile "${profile}" -f "${composeFile}" up -d

    if [[ $? -eq 0 ]]; then
        logMessage "Successfully started ${appName} ${profile}@${VERSION}"
    else
        logError "Failed to start ${appName} ${profile}@${VERSION}"
    fi
}


function stopTestStack {
    local composeFile="$1"
    local profile="$2"
    local targetDir=$(dirname "${composeFile}")

    local appVersion=$(basename "${targetDir}")
    local appName=$(basename $(echo ${targetDir} | awk -F "${appVersion}" '{print $1}'))
    export VERSION=${appVersion}

    logMessage "Stopping ${profile}@${VERSION} profile..."
    docker compose --profile "${profile}" -f "${composeFile}" down

    if [[ $? -eq 0 ]]; then
        logMessage "Successfully stopped ${appName} ${profile}@${VERSION}"
    else
        logError "Failed to stop ${appName} ${profile}@${VERSION}"
    fi

    if [[ -x "${targetDir}/setup.sh" ]];then
        logWarning "Running clear script..."
        "${targetDir}/setup.sh" clear ${profile}
    else
        logWarning "Clear script is missing or could not be found"
        logWarning "It is possible that leftover files remain - ${appName} ${profile}@${VERSION}"
    fi
}

function restartTestStack {
    local composeFile="$1"
    local profile="$2"
    local targetDir=$(dirname "${composeFile}")

    local appVersion=$(basename "${targetDir}")
    local appName=$(basename $(echo ${targetDir} | awk -F "${appVersion}" '{print $1}'))
    export VERSION=${appVersion}

    logMessage "Stopping ${profile}@${VERSION} profile..."
    docker compose --profile "${profile}" -f "${composeFile}" down

    if [[ $? -eq 0 ]]; then
        logMessage "Successfully stopped ${appName} ${profile}@${VERSION}"
    else
        logError "Failed to stop ${appName} ${profile}@${VERSION}"
    fi

    logMessage "Starting ${profile}@${VERSION} profile..."
    docker compose --profile "${profile}" -f "${composeFile}" up -d

    if [[ $? -eq 0 ]]; then
        logMessage "Successfully started ${appName} ${profile}@${VERSION}"
    else
        logError "Failed to start ${appName} ${profile}@${VERSION}"
    fi
}

function testComposeStack {
    local composeFile="$1"
    local timeout="${2:-60}"
    local targetDir=$(dirname "${composeFile}")

    # init the image build
    buildContainerImage "${composeFile}"

    local availableProfiles=($(getDockerComposeProfiles "${composeFile}"))
    if [[ -z "${availableProfiles}" ]];then
        logError "Could not retrieve docker compose profiles from ${composeFile}"
    fi

    for profile in "${availableProfiles[@]}";do
        logMessage "Running health checks for ${profile}..."

        # pre-clear existing test deployments
        logWarning "Running pre-clear procedure for test deployments"
        stopTestStack "${composeFile}" "${profile}"

        startTestStack "${composeFile}" "${profile}"

        if checkStackHealth "${composeFile}" "${profile}" "${timeout}";then
            logMessage "Health check PASSED for ${profile}"
            stopTestStack "${composeFile}" "${profile}"

            updateJsonProperty "status" "tested" "${targetDir}/VERSION"
        else
            logWarning "A container failed health validation"
            getComposeLogs "${composeFile}" "${profile}"

            updateJsonProperty "status" "failed" "${targetDir}/VERSION"
            logError "Health check FAILED for ${profile}"
        fi
    done

    logMessage "Automated test procedure completed for all profiles in ${composeFile}"
    return 0
}

function checkContainerHealth {
    local container="$1"
    local timeout="${2:-60}"
    local elapsed=0
    local interval=5

    logMessage "Waiting for container ${container} to be healthy (timeout: ${timeout}s)..."

    while [[ ${elapsed} -lt ${timeout} ]]; do
        local health=$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null)

        if [[ "${health}" == "healthy" ]]; then
            logMessage "Container ${container} is healthy"
            return 0
        fi

        sleep ${interval}
        elapsed=$((elapsed + interval))
        logMessage "Waiting... (${elapsed}/${timeout}s, status: ${health:-unknown})"
    done

    logError "Container ${container} did not become healthy within ${timeout}s"
}

function checkStackHealth {
    local composeFile="$1"
    local profile="$2"
    local timeout="${3:-60}"

    logMessage "Checking health for profile: ${profile}"

    # get all container IDs for this profile
    local containers=($(docker compose --profile "${profile}" -f "${composeFile}" config --services | \
        xargs -I {} docker compose -f "${composeFile}" ps -q {} 2>/dev/null))

    if [[ -z "${containers}" ]]; then
        logError "No containers found for profile ${profile}"
    fi

    local allHealthy=true
    for container in "${containers[@]}"; do
        if ! checkContainerHealth "${container}" "${timeout}"; then
            allHealthy=false
        fi
    done

    if ${allHealthy}; then
        logMessage "All containers are healthy"
    else
        logError "Some containers are not healthy"
    fi
}

function pushImage {
    local composeFile="$1"

    local targetDir=$(dirname "${composeFile}")

    local image=$(grep "image:" "${composeFile}" | head -1 | awk '{print $2}' | cut -d ":" -f1)
    if [[ -z "${image}" ]]; then
        logError "Could not extract image name from ${composeFile}"
    fi

    local version=$(basename "${targetDir}")
    if [[ -z "${version}" ]];then
        logError "Could not obtain build version from ${targetDir}/VERSION"
    fi

    logMessage "Pushing ${image}:${version}..."

    if ! retryCommand 3 5 "docker push ${image}:${version}"; then
        logError "Failed to push ${image}:${version}"
    fi

    logMessage "Successfully pushed ${image}:${version}"

    # update latest tag
    logMessage "Tagging and pushing as latest..."
    docker tag "${image}:${version}" "${image}:latest"

    if retryCommand 3 5 "docker push ${image}:latest"; then
        logMessage "Successfully pushed ${image}:latest"
    else
        logError "Failed to push ${image}:latest"
    fi
}
