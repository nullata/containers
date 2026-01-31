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
