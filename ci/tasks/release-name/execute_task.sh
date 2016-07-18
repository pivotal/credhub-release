#!/bin/bash

set -exu

RELEASE_NAME_OUTPUT=$(mktemp -d -t release-name-output)

fly \
  -t private \
  execute \
  -c task.yml \
  -i task-repo=../../.. \
  -o release-name-output=$RELEASE_NAME_OUTPUT
