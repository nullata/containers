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

action=$1
profile=$2

if [[ -z ${action// /} ]];then
    logError "$0: Action must be specified"
fi

if [[ -z ${profile// /} ]];then
    logError "$0: Profile must be specified"
fi

key="${action}:${profile}"
case "${key}" in
    init:test-single)
        mkDirs "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test"
        chown 1001:1001 "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test"
        ;;
    init:test-cluster)
        mkDirs "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-node1" "${NULLATA_TEST_BUILD_DIR}/backup/nullata-galera-test" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-node2" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-node3"
        chown 1001:1001 "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-node1" "${NULLATA_TEST_BUILD_DIR}/backup/nullata-galera-test" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-node2" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-node3"
        ;;
    init:test-seed)
        mkDirs "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-seed0" "${NULLATA_TEST_BUILD_DIR}/backup/nullata-galera-test" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-join1"
        chown 1001:1001 "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-seed0" "${NULLATA_TEST_BUILD_DIR}/backup/nullata-galera-test" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-join1"
        ;;
    clear:test-single)
        rmDirs "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test"
        ;;
    clear:test-cluster)
        rmDirs "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-node1" "${NULLATA_TEST_BUILD_DIR}/backup/nullata-galera-test" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-node2" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-node3"
        ;;
    clear:test-seed)
        rmDirs "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-seed0" "${NULLATA_TEST_BUILD_DIR}/backup/nullata-galera-test" "${NULLATA_TEST_BUILD_DIR}/nullata-galera-test-join1"
        ;;
    *)
      logError "$0: Unsupported: ${key}"
      ;;
esac
