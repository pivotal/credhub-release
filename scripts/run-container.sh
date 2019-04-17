#!/usr/bin/env bash

set -ex

docker run \
       --interactive \
       --tty \
       --name credhub \
       --publish 9000:9000 \
       credhub
