#!/usr/bin/env bash

set -u

export PATH=/var/vcap/bosh/bin:/var/vcap/jobs/credhub/bin:$PATH

monit restart credhub
exec /var/vcap/jobs/credhub/bin/bbr/post-bbr-start
