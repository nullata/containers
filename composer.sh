#!/usr/bin/env bash
# Copyright (c) 2025 NullSCA (nullata)
# Licensed under the Elastic License 2.0
# See LICENSE-SCRIPTS for details

########################################
# source environment and libraries
########################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/set-env.sh"

function help {
    local composeYml=${composeFile:-NO_FILE_SPECIFIED}

        cat <<EOF
Usage: $0 <command> <compose-file> <profile> [options]

Commands:
    start   - Start the application
    stop    - Stop the application
    restart - Restart the application
    status  - Show running status
    logs    - Show application logs
    build   - Build the application (does not require profile)
    test    - Run each available profile sequentially, do health checks & auto-cleanup afterwards (does not require profile)
    push    - Push image to DockerHub (requires version)
    help    - Show this help message

Arguments:
    compose-file - Path to docker-compose.yml
    profile      - Docker Compose profile to use

Available profiles (${composeYml}): ${composeProfiles:-<specify compose file to see profiles>}


Environment Variables:
    NULLATA_DEBUG - Enable debug logging (true/false)
    NULLATA_TEST_BUILD_DIR - Base directory for test data
EOF
}

########################################
# runtime requirements validation
########################################
requireCommands docker yq jq

if ! dockerActive; then
    logError "Docker daemon is not running"
fi

########################################
# input vars
########################################
command="$1"
composeFile="$2"

if [[ -z "${command}" ]] || [[ "${command}" == "help" ]]; then
    help
    exit 0
fi

if [[ -z "${composeFile}" ]] || [[ ! -f "${composeFile}" ]]; then
    logError "Compose file not specified or does not exist: ${composeFile}"
fi

if [[ "${command}" != "help" ]] && [[ "${command}" != "build" ]] && [[ "${command}" != "test" ]] && [[ "${command}" != "push" ]]; then
    profile="$3"
    if [[ -z "${profile}" ]]; then
        logError "Profile must be specified"
    fi

    if ! validateDockerProfile "${composeFile}" "${profile}"; then
        availableProfiles=$(getDockerComposeProfiles "${composeFile}")
        logError "Invalid docker compose profile: ${profile}. Available profiles are: ${availableProfiles}"
    fi
fi

case "${command}" in
    start)
        startTestStack "${composeFile}" "${profile}"
    ;;
    stop)
        stopTestStack "${composeFile}" "${profile}"
    ;;
    restart)
        restartTestStack "${composeFile}" "${profile}"
    ;;
    status)
        getComposeStatus "${composeFile}" "${profile}"
    ;;
    logs)
        getComposeLogs "${composeFile}" "${profile}" "${4:-false}"
    ;;
    build)
        buildContainerImage "${composeFile}"
    ;;
    test)
        testComposeStack "${composeFile}" "${TEST_STACK_TIMEOUT_PD_S:-60}"
    ;;
    push)
        pushImage "${composeFile}"
    ;;
    *)
        echo "Unknown command: ${command}"
        help
        exit 1
    ;;
esac
