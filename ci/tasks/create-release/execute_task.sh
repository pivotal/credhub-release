#!/bin/bash

set -exu

fly \
  -t private \
  execute \
  -c task.yml \
  -i release-repo=../../.. \
