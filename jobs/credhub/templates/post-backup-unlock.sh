#!/usr/bin/env bash

set -u

export PATH=/var/vcap/bosh/bin:$PATH

monit restart credhub

echo "waiting for credhub to restart"

/var/vcap/jobs/credhub/bin/post-start