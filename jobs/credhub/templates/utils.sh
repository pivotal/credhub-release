#!/bin/bash

# This sends stdout and stderr to /var/vcap/sys/log.
function tee_output_to_sys_log() {
  log_directory="$1"
  log_name="$2"

  exec > >(tee -a >(logger -p user.info -t "vcap.${log_name}.stdout") | prepend_rfc3339_datetime >>"${log_directory}/${log_name}.stdout.log")
  exec 2> >(tee -a >(logger -p user.error -t "vcap.${log_name}.stderr") | prepend_rfc3339_datetime >>"${log_directory}/${log_name}.stderr.log")
}

function prepend_rfc3339_datetime() {
  perl -ne 'BEGIN { use Time::HiRes "time"; use POSIX "strftime"; STDOUT->autoflush(1) }; my $t = time; my $fsec = sprintf ".%09d", ($t-int($t))*1000000000; my $time = strftime("[%Y-%m-%dT%H:%M:%S".$fsec."Z]", localtime $t); print("$time $_")'
}