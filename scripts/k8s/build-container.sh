#!/usr/bin/env bash

set -exuo pipefail

cd "$( dirname "${BASH_SOURCE[0]}" )/../.."
docker build src/credhub -f Dockerfile -t pcfseceng/k8s-credhub
