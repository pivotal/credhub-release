#!/bin/bash

set -exu

DEV_RELEASES_DIR=$(mktemp -d -t cm-release-execute-task)
mv ../../../dev_releases $DEV_RELEASES_DIR/dev_releases

trap "mv $DEV_RELEASES_DIR/dev_releases ../../../dev_releases" EXIT

fly -t private execute -c task.yml -i cm-release=../../..
