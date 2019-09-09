#! /bin/bash

newFile=${2:-"/tmp/credhub_security_events_with_timestamps.log"}
touch $newFile

while IFS= read -r line; do
    timestamp="$(echo $line | awk '{print $3}' | cut -d "=" -f2 | xargs date -r)"
    echo $line | sed -E "s/rt=[0-9]*/rt=\"${timestamp}\"/" >> "$newFile"
done < "$1"

echo "Converted file saved at $newFile"
