#!/bin/bash

set -exu

temp_dir=$(mktemp -d -t release-name-output)

export OUTPUT_PATH=temp_dir
export VERSION=sample_version
export RELEASE_NAME=sample_name

fly \
  -t private \
  execute \
  -c task.yml \
  -i release-dir=../../.. \
  -o create-release-output=temp_dir
