#!/usr/bin/env bash

# strict mode
# set -euo pipefail
set -e

# get the repository root directory
export NULLATA_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# base directory for test builds
export NULLATA_TEST_BUILD_DIR="${NULLATA_TEST_BUILD_DIR:-/opt/services/database}"

# hardened build suffix
export NULLATA_HARDENED_SUFFIX="${NULLATA_HARDENED_SUFFIX:-hardened-experimental}"

# logging
export NULLATA_LOG_DIR="${NULLATA_LOG_DIR:-/var/log/nullata-builds}"

# prevent log file override between scripts
# leave empty to not create a log file
if [[ -z ${NULLATA_LOG_FILE} ]];then
    # example
    # export NULLATA_LOG_FILE="${NULLATA_LOG_DIR}/build--$(date +%Y-%m-%d).log"
    export NULLATA_LOG_FILE=""
fi

# debug mode
export NULLATA_DEBUG="${NULLATA_DEBUG:-false}"

# override test health check wait pd
export TEST_STACK_TIMEOUT_PD_S=90

# create log directory if it doesnt exist
mkdir -p "${NULLATA_LOG_DIR}" 2>/dev/null || true

# source common libraries
source "${NULLATA_REPO_DIR}/lib/logging.sh"
source "${NULLATA_REPO_DIR}/lib/common.sh"
source "${NULLATA_REPO_DIR}/lib/docker.sh"
source "${NULLATA_REPO_DIR}/lib/versioning.sh"

logMessage "Environment initialized"
logMessage "NULLATA_REPO_DIR: ${NULLATA_REPO_DIR}"
logMessage "NULLATA_TEST_BUILD_DIR: ${NULLATA_TEST_BUILD_DIR}"
logMessage "NULLATA_LOG_FILE: ${NULLATA_LOG_FILE}"
