#!/usr/bin/env bash

export PATH=/var/vcap/bosh/bin:$PATH

monit stop credhub
exec /var/vcap/jobs/credhub/bin/bbr/wait-for-stop