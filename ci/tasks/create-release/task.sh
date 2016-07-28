#!/bin/bash

set -eux

echo $PWD

pushd release-repo
    bosh -n create release --name credhub --force --with-tarball --timestamp-version

    # create release tarball as well so it can be uploaded to s3
    cd dev_releases/credhub
    RELEASE_TARBALL=$(ls -t *.tgz | head -1)
popd

cp release-repo/dev_releases/credhub/$RELEASE_TARBALL $OUTPUT_PATH
expr "$RELEASE_TARBALL" : "credhub-\(.*\)\.tgz" | tee /tmp/version
cp /tmp/version $OUTPUT_PATH
