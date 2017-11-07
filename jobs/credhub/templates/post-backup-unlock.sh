#!/usr/bin/env bash

set -u

export PATH=/var/vcap/bosh/bin:$PATH

echo "at start of unlock script for credhub ...."
monit start credhub

echo "waiting for credhub to start after backup"

exec /var/vcap/jobs/credhub/bin/post-start
