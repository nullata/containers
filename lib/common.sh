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

# strict mode
# set -euo pipefail

function commandExists {
    command -v "$1" >/dev/null 2>&1
}

function requireCommands {
    local missing=()
    for cmd in "$@"; do
        if ! commandExists "${cmd}"; then
            missing+=("${cmd}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        logError "Missing required commands: ${missing[*]}"
    fi
}

function getJsonProperty {
    local key="$1"
    local file="${2:-VERSION}"   # default to VERSION in cwd

    if ! [[ -r "${file}" ]]; then
        logError "File '${file}' not found or not readable"
    fi

    # -r removes quotes
    local value=$(jq -r --arg k "${key}" '.[$k]' "${file}" 2>/dev/null)

    # jq returns null if the key doesnt exist
    if [[ "${value}" == "null" ]]; then
        logError "Property '${key}' not found in '${file}'"
    fi

    printf '%s\n' "${value}"
}

function updateJsonProperty {
    local key="$1"
    local value="$2"
    local file="${3:-VERSION}"

    if [[ -z ${key} ]]; then
        logError "${FUNCNAME[0]}: Key must be provided"
    fi
    if [[ -z ${value} ]]; then
        logError "${FUNCNAME[0]}: Value must be provided"
    fi
    if ! [[ -f "${file}" ]]; then
        logError "${FUNCNAME[0]}: File not found: ${file}"
    fi

    jq --arg k "${key}" --arg v "${value}" '.[$k] = $v' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
    logMessage "Updated ${key} to ${value} in ${file}"
}

function mkDirs {
    # create + permissive perms for a list of dirs
    [[ $# -eq 0 ]] && logError "${FUNCNAME[0]}: No arguments provided"
    local dirs=( "$@" )
    logMessage "Creating testing dirs: ${dirs[*]}"
    mkdir -p "${dirs[@]}"

    logMessage "Setting testing dirs permissions: ${dirs[*]}"
    chmod -R 0777 "${dirs[@]}"
}

function rmDirs {
    [[ $# -eq 0 ]] && logError "${FUNCNAME[0]}: No arguments provided"
    local dirs=( "$@" )

    logMessage "Deleting testing dirs: ${dirs[*]}"
    for dir in "${dirs[@]}";do
        if [[ -d ${dir} ]];then
            rm -rf "${dir}"
        fi
    done
}

# retry a command with exponential backoff
function retryCommand {
    local maxAttempts="$1"
    local delay="$2"
    local command="${@:3}"
    local attempt=1

    while [[ ${attempt} -le ${maxAttempts} ]]; do
        logMessage "Attempt ${attempt}/${maxAttempts}: ${command}"

        if eval "${command}"; then
            return 0
        fi

        if [[ ${attempt} -lt ${maxAttempts} ]]; then
            logWarning "Command failed, retrying in ${delay}s..."
            sleep "${delay}"
            delay=$((delay * 2))
        fi

        attempt=$((attempt + 1))
    done

    return 1
}

function updateLicenseYear {
    local targetDir="$1"
    local currentYear
    currentYear=$(date +%Y)

    if [[ -z "${targetDir}" ]]; then
        logError "${FUNCNAME[0]}: Target directory must be provided"
    fi
    if ! [[ -d "${targetDir}" ]]; then
        logError "${FUNCNAME[0]}: Directory not found: ${targetDir}"
    fi

    logMessage "Updating license year to ${currentYear} in: ${targetDir}"

    local count=0
    while IFS= read -r -d '' file; do
        local changed=false

        if grep -q "Modified by nullata [0-9]\{4\}" "${file}" 2>/dev/null; then
            sed -i "s/Modified by nullata [0-9]\{4\}/Modified by nullata ${currentYear}/" "${file}"
            changed=true
        fi

        if grep -q "Copyright (c) [0-9]\{4\} NullSCA" "${file}" 2>/dev/null; then
            sed -i "s/Copyright (c) [0-9]\{4\} NullSCA/Copyright (c) ${currentYear} NullSCA/" "${file}"
            changed=true
        fi

        if ${changed}; then
            count=$((count + 1))
        fi
    done < <(find "${targetDir}" -type f -name "*.sh" -print0)

    logMessage "License year updated in ${count} file(s)"
}

export -f mkDirs
export -f rmDirs
export -f updateLicenseYear
