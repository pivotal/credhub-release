#!/usr/bin/env bash

set -exuo pipefail

cat << EOF > /tmp/credhub-k8s-pod.yml
apiVersion: v1
kind: Pod
metadata:
  name: credhub-k8s
spec:
  containers:
  - name: credhub
    image: pcfseceng/k8s-credhub
EOF

kubectl apply -f /tmp/credhub-k8s-pod.yml
