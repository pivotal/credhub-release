#!/usr/bin/env bash

set -exuo pipefail

docker run \
       --rm \
       --interactive \
       --tty \
       --name credhub \
       --publish 9000:9000 \
       pcfseceng/k8s-credhub
