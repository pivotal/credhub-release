#!/bin/bash

set -eux

cd release_repo

bosh -n create release --name credhub --force --with-tarball --timestamp-version

# create release tarball as well so it can be uploaded to s3
cd dev_releases/credhub
RELEASE_TARBALL=$(ls -t *.tgz | head -1)
cp $RELEASE_TARBALL $PWD/$OUTPUT_PATH
expr "$RELEASE_TARBALL" : "credhub-\(.*\)\.tgz" | tee $PWD/$OUTPUT_PATH/version
