#!/usr/bin/env bash
# Copyright (c) 2025 NullSCA (nullata)
# Licensed under the Elastic License 2.0
# See LICENSE-SCRIPTS for details

########################################
# detect updates and create new build directories
########################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/set-env.sh"

########################################
# Main
########################################
requireCommands curl jq

appsBaseDir="${NULLATA_REPO_DIR}/apps"

if ! [[ -d "${appsBaseDir}" ]]; then
    logError "Apps directory not found: ${appsBaseDir}"
fi

logMessage "Scanning for updates in: ${appsBaseDir}"

# find all directories with VERSION files
for appDir in "${appsBaseDir}"/*; do
    if [[ -d "${appDir}" ]] && [[ -f "${appDir}/VERSION" ]]; then
        checkAppForUpdates "${appDir}"

        if [[ $? -eq 0 ]];then
            # find the latest version directory that was just created
            latestBuild=$(find "${appDir}" -maxdepth 1 -type d -regex '.*/[0-9]+\.[0-9]+\.[0-9]+\(-[0-9]+\)?' | \
                sort -V | \
                tail -n1)

            if [[ -n "${latestBuild}" ]] && [[ -f "${latestBuild}/docker-compose.yml" ]]; then
                logMessage "Testing newly created build: ${latestBuild}"

                if [[ -x ${SCRIPT_DIR}/composer.sh ]];then
                    ${SCRIPT_DIR}/composer.sh test "${latestBuild}/docker-compose.yml"

                    if [[ $? -eq 0 ]];then
                        ${SCRIPT_DIR}/composer.sh push "${latestBuild}/docker-compose.yml"
                    else
                        logError "There was a problem during the build process for: ${SCRIPT_DIR}/composer.sh test ${latestBuild}/docker-compose.yml"
                    fi
                else
                    logError "Composer script lacking execute permissions"
                fi
            else
                logError "Could not find docker-compose.yml in latest build directory: ${latestBuild}/docker-compose.yml"
            fi
        fi
        logBreak  # break line between apps
    fi
done

logMessage "Update check complete"
