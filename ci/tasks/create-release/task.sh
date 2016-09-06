#!/bin/bash

set -eux

WORKING_DIR=${PWD}

if [ -z "$RELEASE_NAME" ]; then
  exit 1
fi

if [ -z "$RELEASE_VERSION_FILE" ]; then
  VERSION_ARG="--timestamp-version"
else
  VERSION=$(cat $RELEASE_VERSION_FILE)
  VERSION_ARG="--version $VERSION"
fi

cd release-dir
bosh create release --with-tarball --name $RELEASE_NAME --force $VERSION_ARG
# upload release to bosh
bosh -t $BOSH_TARGET login $BOSH_USERNAME $BOSH_PASSWORD
bosh target $BOSH_TARGET
bosh upload release

cd dev_releases/$RELEASE_NAME
RELEASE_TARBALL=$(ls -t *.tgz | head -1)
cp $RELEASE_TARBALL $WORKING_DIR/$OUTPUT_PATH
expr "$RELEASE_TARBALL" : "$RELEASE_NAME-\(.*\)\.tgz" | tee $WORKING_DIR/$OUTPUT_PATH/version
