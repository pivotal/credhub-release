#!/bin/bash

set -exu

rm -rf $RELEASE_DIR/dev_releases/*

fly -t private execute -c task.yml -i cm-release=../../..
