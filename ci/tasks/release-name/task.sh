#!/bin/bash

set -eux

binary_name="credhub-release-tarball"
build_number=$(date +%s)

echo ${binary_name} > ${RELEASE_NAME_OUTPUT_PATH}/name
echo ${build_number} > ${RELEASE_NAME_OUTPUT_PATH}/tag
