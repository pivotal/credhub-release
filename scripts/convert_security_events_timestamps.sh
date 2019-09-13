#! /bin/bash

newFile=${2:-"/tmp/credhub_security_events_with_timestamps.log"}
touch "$newFile"

export TZ=UTC

while IFS= read -r line; do
    unixTimestamp="$(echo "$line" | awk '{print $3}' | cut -d "=" -f2)"
    dateTime="$(date -r $((unixTimestamp/1000)))"
    echo "$line" | sed -E "s/rt=[0-9]*/rt=\"${dateTime}\"/" >> "$newFile"
done < "$1"

echo "Converted file saved at $newFile"
