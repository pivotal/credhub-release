#!/bin/bash

set -exu

RELEASE_NAME_OUTPUT=$(mktemp -d -t release-name-output)
FAKE_TARBALLS=$(mktemp -d -t credhub-release-fakes)
touch $FAKE_TARBALLS/credhub-1+dev.1468862844.tgz
touch $FAKE_TARBALLS/version

fly \
  -t private \
  execute \
  -c task.yml \
  -i task-repo=../../.. \
  -i credhub-release-tarball=$FAKE_TARBALLS \
  -o release-name-output=$RELEASE_NAME_OUTPUT
