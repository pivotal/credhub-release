#!/bin/bash

CLIENT_NAME="test"
# Client ID have to be UUID v4
CLIENT_ID=$(uuid -v 4)

FILE_NAME="client-${CLIENT_NAME}-${CLIENT_ID}"

echo "=== ${FILE_NAME} ==="

# private key
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048  -out "./certs/${FILE_NAME}.key"

# CSR
openssl req -new -key "./certs/${FILE_NAME}.key" -out "./certs/${FILE_NAME}.csr" -config eku_config.cnf -subj "/CN=${CLIENT_NAME}/OU=app:${CLIENT_ID}"
# youc can use: -subj "/OU=app:<uuid-v4>/OU=space:<uuid-v4>/OU=organization:<uuid-v4>/CN=<client-name>"

# CA Signature
openssl x509 -req -in "./certs/${FILE_NAME}.csr" -CA "./certs/credhub-clients-ca.cert" -CAkey "./certs/credhub-clients-ca.key" -CAcreateserial -out "./certs/${FILE_NAME}.cert" -days 3650 -extensions v3_ext -extfile eku_config.cnf

openssl x509 -in "./certs/${FILE_NAME}.cert" -text -noout > "./certs/${FILE_NAME}.cert.info"

