#!/usr/bin/env bash
# Copyright (c) 2025 NullSCA (nullata)
# Licensed under the Elastic License 2.0
# See LICENSE-SCRIPTS for details

# strict mode
# set -euo pipefail

function getTimeStamp {
    date +%d-%m-%Y--%H-%M-%S
}

function logBase {
    local message="$1"
    local level="$2"

    if [[ -n "${NULLATA_LOG_FILE}" ]]; then
        printf '[%s] [%s] %s\n' "$(getTimeStamp)" "${level}" "${message}" | tee -a "${NULLATA_LOG_FILE}" >&2
        return
    fi
    echo "[$(getTimeStamp)] [${level}] ${message}" >&2
}

function logMessage {
    logBase "$1" INFO
}

function logError {
    logBase "$1" ERROR
    exit 1
}

function logWarning {
    logBase "$1" WARNING
}

function logBreak {
    logBase "-------------------------------------" "----"
}

export -f getTimeStamp
export -f logBase
export -f logError
export -f logMessage
export -f logWarning
