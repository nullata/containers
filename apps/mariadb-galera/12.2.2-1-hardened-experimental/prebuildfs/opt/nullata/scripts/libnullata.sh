#!/bin/bash
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
# Modified by nullata 2025

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/nullata/scripts/liblog.sh

# Constants
BOLD='\033[1m'

# Functions

########################
# Print the welcome page
# Globals:
#   DISABLE_WELCOME_MESSAGE
#   NULLATA_APP_NAME
# Arguments:
#   None
# Returns:
#   None
#########################
print_welcome_page() {
    if [[ -z "${DISABLE_WELCOME_MESSAGE:-}" ]]; then
        if [[ -n "$NULLATA_APP_NAME" ]]; then
            print_image_welcome_page
        fi
    fi
}

########################
# Print the welcome page for a Nullata Docker image
# Globals:
#   NULLATA_APP_NAME
# Arguments:
#   None
# Returns:
#   None
#########################
print_image_welcome_page() {
    local github_url="https://github.com/nullata/containers"

    info ""
    info "${BOLD}Welcome to the Nullata ${NULLATA_APP_NAME} container${RESET}"
    info "Subscribe to project updates by watching ${BOLD}${github_url}${RESET}"
    info ""
}

