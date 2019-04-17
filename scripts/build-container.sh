#!/usr/bin/env bash

set -ex

cd "$( dirname "${BASH_SOURCE[0]}" )/.."
docker build src/credhub -f Dockerfile -t credhub
