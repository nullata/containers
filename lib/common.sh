#!/usr/bin/env bash
# Copyright (c) 2025 NullSCA (nullata)
# Licensed under the Elastic License 2.0
# See LICENSE-SCRIPTS for details

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

export -f mkDirs
export -f rmDirs
