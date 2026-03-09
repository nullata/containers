#!/usr/bin/env bash
# Copyright (c) 2025 NullSCA (nullata)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

                testComposeStack "${latestBuild}/docker-compose.yml" "${TEST_STACK_TIMEOUT_PD_S:-60}"

                if [[ $? -eq 0 ]];then
                    pushImage "${latestBuild}/docker-compose.yml"

                    # create hardened build
                    createHardenedBuild "${latestBuild}"
                else
                    logError "There was a problem during the build process for: ${SCRIPT_DIR}/composer.sh test ${latestBuild}/docker-compose.yml"
                fi
            else
                logError "Could not find docker-compose.yml in latest build directory: ${latestBuild}/docker-compose.yml"
            fi
        fi
        logBreak  # break line between apps
    fi
done

logMessage "Running cleanup to maintain version limits..."
cleanupAllApps
logBreak

logMessage "Update check complete"
