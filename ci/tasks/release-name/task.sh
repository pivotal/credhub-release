#!/bin/bash

set -eux

binary_name="credhub-release-tarball"
build_number=$(ls credhub-release-tarball | sed -e "s/.*\.\([0-9]*\)\.tgz/\1/g")

echo ${binary_name} > ${RELEASE_NAME_OUTPUT_PATH}/name
echo ${build_number} > ${RELEASE_NAME_OUTPUT_PATH}/tag
