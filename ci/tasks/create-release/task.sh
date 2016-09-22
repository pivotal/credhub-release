#!/bin/bash

set -eux

WORKING_DIR=${PWD}

if [ -z "$RELEASE_NAME" ]; then
  exit 1
fi

if [ -z "$RELEASE_VERSION_FILE" ]; then
  TIMESTAMP_OR_VERSION="--timestamp-version"
else
  export VERSION=$(cat $RELEASE_VERSION_FILE)
  TIMESTAMP_OR_VERSION="--version $VERSION"
fi

pushd release-dir
    bosh create release --with-tarball --name $RELEASE_NAME --force $TIMESTAMP_OR_VERSION
    # upload release to bosh
    bosh -t $BOSH_TARGET login $BOSH_USERNAME $BOSH_PASSWORD
    bosh target $BOSH_TARGET
    bosh upload release

    pushd dev_releases/$RELEASE_NAME
        RELEASE_TARBALL=$(ls -t *.tgz | head -1)
        cp $RELEASE_TARBALL $WORKING_DIR/$OUTPUT_PATH
        expr "$RELEASE_TARBALL" : "$RELEASE_NAME-\(.*\)\.tgz" | tee $WORKING_DIR/$OUTPUT_PATH/version
    popd
popd
