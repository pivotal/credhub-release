#!/usr/bin/env bash

set -u

export PATH=/var/vcap/bosh/bin:/var/vcap/jobs/credhub/bin:$PATH

echo "waiting for credhub to restart"

exec /var/vcap/jobs/credhub/bin/post-start
