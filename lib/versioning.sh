#!/usr/bin/env bash
# Copyright (c) 2025 NullSCA (nullata)
# Licensed under the Elastic License 2.0
# See LICENSE-SCRIPTS for details

# strict mode
# set -euo pipefail

function extractVersionFromResponse {
    local type="$1"
    local url="$2"
    local field="$3"
    local pattern="$4"

    local response=$(curl -s "${url}")

    if [[ -z "${response}" ]]; then
        return 1
    fi

    case "${type}" in
        github_latest_release)
            # extract fields from object
            local value=$(echo "${response}" | jq -r ".${field}")
            if [[ "${value}" == "null" || -z "${value}" ]]; then
                return 1
            fi
            # extract version
            if [[ "${value}" =~ ${pattern} ]]; then
                echo "${BASH_REMATCH[1]}"
                return 0
            fi
            ;;

        github_tags|github_releases)
            # array of objects >> iterate and find versions
            local versions=()
            while IFS= read -r item; do
                local value=$(echo "${item}" | jq -r ".${field}")
                if [[ "${value}" != "null" && -n "${value}" ]]; then
                    if [[ "${value}" =~ ${pattern} ]]; then
                        versions+=("${BASH_REMATCH[1]}")
                    fi
                fi
            done < <(echo "${response}" | jq -c '.[]')

            # sort & get latest
            if [[ ${#versions[@]} -gt 0 ]]; then
                printf '%s\n' "${versions[@]}" | sort -V | tail -n1
                return 0
            fi
            ;;

        *)
            return 1
            ;;
    esac

    return 1
}

function compareVersions {
    local current="$1"
    local latest="$2"

    if [[ "${current}" == "${latest}" ]]; then
        return 1  # same version
    fi

    # -V to compare semantic versions
    local newer=$(printf "%s\n%s" "${current}" "${latest}" | sort -V | tail -n1)

    if [[ "${newer}" == "${latest}" ]]; then
        return 0  # update available
    fi

    return 1  # current is newer
}

function checkAppForUpdates {
    local appDir="$1"
    local masterVersionFile="${appDir}/VERSION"

    if ! [[ -f "${masterVersionFile}" ]]; then
        logWarning "No VERSION file found in ${appDir}, skipping"
        return
    fi

    local appName=$(jq -r '.app_name' "${masterVersionFile}")
    logMessage "Checking for updates: ${appName} (${appDir})"

    local components=$(jq -c '.components[]' "${masterVersionFile}")
    local anyUpdateFound=false
    local primaryVersion=""
    local fetchedVersionsJson="{"
    local firstItem=true

    while IFS= read -r component; do
        local name=$(echo "${component}" | jq -r '.name')
        local isPrimary=$(echo "${component}" | jq -r '.primary')
        local currentVersion=$(echo "${component}" | jq -r '.latest_version')

        local sourceType=$(echo "${component}" | jq -r '.version_source.type')
        local sourceUrl=$(echo "${component}" | jq -r '.version_source.url')
        local sourceField=$(echo "${component}" | jq -r '.version_source.field')
        local sourcePattern=$(echo "${component}" | jq -r '.version_source.pattern')

        logMessage "  Checking ${name}: current=${currentVersion} (primary=${isPrimary})"

        local latestVersion=$(extractVersionFromResponse "${sourceType}" "${sourceUrl}" "${sourceField}" "${sourcePattern}")

        if [[ -z "${latestVersion}" ]]; then
            logError "  Failed to fetch latest version for ${name} (source type: ${sourceType}) - aborting update check for ${appName}"
        fi

        logMessage "  Latest ${name}: ${latestVersion}"

        # track primary version for directory naming
        if [[ "${isPrimary}" == "true" ]]; then
            primaryVersion="${latestVersion}"
        fi

        # build json for fetched versions
        if [[ "${firstItem}" == "true" ]]; then
            fetchedVersionsJson+="\"${name}\":\"${latestVersion}\""
            firstItem=false
        else
            fetchedVersionsJson+=",\"${name}\":\"${latestVersion}\""
        fi

        # compare versions - trigger on ANY update
        if compareVersions "${currentVersion}" "${latestVersion}"; then
            logMessage "  Update available for ${name}: ${currentVersion} -> ${latestVersion}"
            anyUpdateFound=true
        else
            logMessage "  ${name} is up to date"
        fi
    done <<< "${components}"

    fetchedVersionsJson+="}"

    # create new build directory if ANY component updated
    if ${anyUpdateFound}; then
        logMessage "Component update(s) detected, creating new build directory"

        # check if primary version directory already exists
        local newBuildDir="${appDir}/${primaryVersion}"
        local buildVersion="${primaryVersion}"

        if [[ -d "${newBuildDir}" ]]; then
            # find next available build suffix
            local buildNum=1
            while [[ -d "${appDir}/${primaryVersion}-${buildNum}" ]]; do
                buildNum=$((buildNum + 1))
            done
            buildVersion="${primaryVersion}-${buildNum}"
            logMessage "  Primary version ${primaryVersion} already exists, using ${buildVersion}"
        fi

        newBuildDir=$(createNewBuildDirectory "${appDir}" "${buildVersion}")

        if [[ -n "${newBuildDir}" ]]; then
            updateMasterVersionFile "${masterVersionFile}" "${fetchedVersionsJson}"
            updateNewBuildFiles "${newBuildDir}" "${masterVersionFile}"
            logMessage "Build directory ${newBuildDir} created and updated successfully"
        fi
    else
        logMessage "No component updates found for ${appName}"
        return 1
    fi
}

function createNewBuildDirectory {
    local appDir="$1"
    local newVersion="$2"

    # find the latest existing version directory
    local latestExisting=$(find "${appDir}" -maxdepth 1 -type d -regex '.*/[0-9]+\.[0-9]+\.[0-9]+' | \
        sort -V | \
        tail -n1)

    if [[ -z "${latestExisting}" ]]; then
        logError "Could not find existing version directory in ${appDir}"
    fi

    local existingVersion=$(basename "${latestExisting}")
    local newBuildDir="${appDir}/${newVersion}"

    if [[ -d "${newBuildDir}" ]]; then
        logWarning "Build directory already exists: ${newBuildDir}"
        return 1
    fi

    logMessage "Creating new build directory: ${newBuildDir}"
    logMessage "  Copying from: ${latestExisting} (${existingVersion})"

    cp -R "${latestExisting}" "${newBuildDir}"

    if [[ $? -eq 0 ]]; then
        logMessage "Successfully created ${newBuildDir}"
        echo "${newBuildDir}"  # stdout for capture
    else
        logError "Failed to create new build directory"
    fi
}

function updateNewBuildFiles {
    local newBuildDir="$1"
    local masterVersionFile="$2"

    logMessage "Updating files in ${newBuildDir}..."

    # get all components and their latest versions
    local components=$(jq -c '.components[]' "${masterVersionFile}")

    # update Dockerfile args
    local dockerfile="${newBuildDir}/Dockerfile"
    if [[ -f "${dockerfile}" ]]; then
        logMessage "  Updating Dockerfile ARG values..."

        while IFS= read -r component; do
            local name=$(echo "${component}" | jq -r '.name')
            local latestVersion=$(echo "${component}" | jq -r '.latest_version')

            # convert component name to uppercase for ARG name
            local argName=$(echo "${name}" | tr '[:lower:]' '[:upper:]')_VERSION

            # update ARG line in Dockerfile
            if grep -q "ARG ${argName}=" "${dockerfile}"; then
                sed -i "s/ARG ${argName}=.*/ARG ${argName}=${latestVersion}/" "${dockerfile}"
                logMessage "    Updated ${argName}=${latestVersion}"
            else
                logWarning "    ARG ${argName} not found in Dockerfile"
            fi
        done <<< "${components}"
    else
        logWarning "  Dockerfile not found: ${dockerfile}"
    fi

    # update VERSION file in new build directory
    local versionFile="${newBuildDir}/VERSION"
    if [[ -f "${versionFile}" ]]; then
        logMessage "  Updating VERSION file..."

        # update build_version (primary component version)
        local primaryVersion=$(jq -r '.components[] | select(.primary==true) | .latest_version' "${masterVersionFile}")
        updateJsonProperty "build_version" "${primaryVersion}" "${versionFile}"

        # update each component version in VERSION file
        while IFS= read -r component; do
            local name=$(echo "${component}" | jq -r '.name')
            local latestVersion=$(echo "${component}" | jq -r '.latest_version')

            # Check if this component exists as a key in VERSION file
            if jq -e "has(\"${name}\")" "${versionFile}" >/dev/null 2>&1; then
                updateJsonProperty "${name}" "${latestVersion}" "${versionFile}"
            fi
        done <<< "${components}"

        # reset status to untested
        updateJsonProperty "status" "untested" "${versionFile}"

        # update build_date to today
        local today=$(date +%Y-%m-%d)
        updateJsonProperty "build_date" "${today}" "${versionFile}"

        logMessage "  VERSION file updated"
    else
        logWarning "  VERSION file not found: ${versionFile}"
    fi
}

function updateMasterVersionFile {
    local masterVersionFile="$1"
    local fetchedVersions="$2"  # json string with component:version pairs

    logMessage "Updating master VERSION file: ${masterVersionFile}"

    local components=$(jq -c '.components[]' "${masterVersionFile}")
    local tempFile="${masterVersionFile}.tmp"

    # start with the current file
    cp "${masterVersionFile}" "${tempFile}"

    # update each components latest_version
    while IFS= read -r component; do
        local name=$(echo "${component}" | jq -r '.name')
        local newVersion=$(echo "${fetchedVersions}" | jq -r ".${name}")

        if [[ "${newVersion}" != "null" && -n "${newVersion}" ]]; then
            # update the latest_version for this component
            jq --arg name "${name}" --arg ver "${newVersion}" \
                '(.components[] | select(.name==$name) | .latest_version) = $ver' \
                "${tempFile}" > "${tempFile}.new" && mv "${tempFile}.new" "${tempFile}"

            logMessage "  Updated ${name}: ${newVersion}"
        fi
    done <<< "${components}"

    mv "${tempFile}" "${masterVersionFile}"
    logMessage "Master VERSION file updated"
}

function createHardenedBuild {
    local standardBuildDir="$1"
    local appDir=$(dirname "${standardBuildDir}")
    local standardVersion=$(basename "${standardBuildDir}")

    logMessage "Attempting to creating a hardened variant for ${standardVersion}"

    # Find most recent hardened build to use as template
    local latestHardened=$(find "${appDir}" -maxdepth 1 -type d \
        -regex ".*-${NULLATA_HARDENED_SUFFIX}" | sort -V | tail -n1)

    if [[ -z "${latestHardened}" ]]; then
        logWarning "No previous hardened build found for ${appDir}"
        logWarning "Skipping hardened build creation. Create initial hardened build manually."
        return 0
    fi

    logMessage "Using template from: ${latestHardened}"

    local hardenedVersion="${standardVersion}-${NULLATA_HARDENED_SUFFIX}"
    local hardenedBuildDir="${appDir}/${hardenedVersion}"

    if [[ -d "${hardenedBuildDir}" ]]; then
        logWarning "Hardened build directory already exists: ${hardenedBuildDir}"
        return 1
    fi

    logMessage "Creating hardened build directory: ${hardenedBuildDir}"
    mkdir -p "${hardenedBuildDir}"

    logMessage "Copying hardened contents into: ${hardenedBuildDir}"
    cp -R "${latestHardened}"/* "${hardenedBuildDir}/"

    logMessage "Adding execution rights to setup script"
    chmod +x "${hardenedBuildDir}/setup.sh"

    # update Dockerfile ARG versions to match standard build
    logMessage "  Updating Dockerfile ARG versions..."
    local dockerfile="${hardenedBuildDir}/Dockerfile"

    # get master VERSION file to extract component versions
    local masterVersionFile="${appDir}/VERSION"
    local components=$(jq -c '.components[]' "${masterVersionFile}")

    while IFS= read -r component; do
        local name=$(echo "${component}" | jq -r '.name')
        local latestVersion=$(echo "${component}" | jq -r '.latest_version')

        # convert component name to uppercase for ARG name
        local argName=$(echo "${name}" | tr '[:lower:]' '[:upper:]')_VERSION

        # update ARG line in Dockerfile
        if grep -q "ARG ${argName}=" "${dockerfile}"; then
            sed -i "s/ARG ${argName}=.*/ARG ${argName}=${latestVersion}/" "${dockerfile}"
            logMessage "  Updated ${argName}=${latestVersion}"
        else
            logWarning "  ARG ${argName} not found in Dockerfile"
        fi
    done <<< "${components}"

    # update VERSION file for new hardened build
    logMessage "Updating VERSION file..."
    local versionFile="${hardenedBuildDir}/VERSION"
    local today=$(date +%Y-%m-%d)

    # update build_version to match new standard version
    updateJsonProperty "build_version" "${standardVersion}" "${versionFile}"

    # update component versions from master VERSION
    while IFS= read -r component; do
        local name=$(echo "${component}" | jq -r '.name')
        local latestVersion=$(echo "${component}" | jq -r '.latest_version')

        # update component version in VERSION file if it exists
        if jq -e "has(\"${name}\")" "${versionFile}" >/dev/null 2>&1; then
            updateJsonProperty "${name}" "${latestVersion}" "${versionFile}"
        fi
    done <<< "${components}"

    # reset status to untested and update build date
    updateJsonProperty "status" "untested" "${versionFile}"
    updateJsonProperty "build_date" "${today}" "${versionFile}"

    logMessage "Hardened build directory created: ${hardenedBuildDir}"

    # -----------
    # build; test; and push the hardened variant
    # -----------
    local composeFile="${hardenedBuildDir}/docker-compose.yml"

    if ! [[ -f "${composeFile}" ]]; then
        logError "docker-compose.yml not found in hardened build: ${composeFile}"
    fi

    logMessage "Building hardened variant..."
    buildContainerImage "${composeFile}"

    if [[ $? -ne 0 ]]; then
        logError "Failed to build hardened variant"
    fi

    logMessage "Testing hardened variant..."
    if testComposeStack "${composeFile}" "${TEST_STACK_TIMEOUT_PD_S:-90}"; then
        logMessage "Hardened build tests PASSED"

        # push hardened build (version tag only --- no latest)
        logMessage "Pushing hardened variant..."
        pushHardenedImage "${composeFile}" "${hardenedVersion}"

        logMessage "Hardened variant complete: ${hardenedVersion}"
    else
        updateJsonProperty "status" "failed" "${versionFile}"
        logError "Hardened build tests FAILED for ${hardenedVersion}"
    fi
}

function pushHardenedImage {
    local composeFile="$1"
    local hardenedVersion="$2"

    local targetDir=$(dirname "${composeFile}")
    local image=$(grep "image:" "${composeFile}" | head -1 | awk '{print $2}' | cut -d ":" -f1)

    if [[ -z "${image}" ]]; then
        logError "Could not extract image name from ${composeFile}"
    fi

    logMessage "Pushing ${image}:${hardenedVersion}..."

    if ! retryCommand 3 5 "docker push ${image}:${hardenedVersion}"; then
        logError "Failed to push ${image}:${hardenedVersion}"
    fi

    logMessage "Successfully pushed ${image}:${hardenedVersion}"
    logMessage "Note: Hardened builds do not update the 'latest' tag"
}
