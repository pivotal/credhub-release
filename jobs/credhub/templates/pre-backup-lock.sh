#!/usr/bin/env bash

export PATH=/var/vcap/bosh/bin:$PATH

monit stop credhub
sleep 60