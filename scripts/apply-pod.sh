#!/usr/bin/env bash

set -ex

cat << EOF > /tmp/credhub-k8s-pod.yml
apiVersion: v1
kind: Pod
metadata:
  name: credhub-k8s
spec:
  containers:
  - name: credhub
    image: ankeesler/credhub
EOF

kubectl apply -f /tmp/credhub-k8s-pod.yml
