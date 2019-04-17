#!/usr/bin/env bash

set -ex

docker run \
       --rm \
       --interactive \
       --tty \
       --name credhub \
       --publish 9000:9000 \
       credhub
