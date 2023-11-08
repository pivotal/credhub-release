#!/bin/bash

mkdir -p ./certs

openssl req -x509 -newkey rsa:4096 -keyout ./certs/credhub-clients-ca.key -out ./certs/credhub-clients-ca.cert -days 3650 -nodes -subj "/CN=CredhubClientsCA"
