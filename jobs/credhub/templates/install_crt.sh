#!/bin/bash

set -e

## BEGIN CERTIFICATE INSTALLATION

export JDK_HOME=/var/vcap/packages/openjdk_1.8.0/jdk

CERT_FILE=$1
PRIVATE_KEY_FILE=$2

CERT_ALIAS=credhub_ssl_cert
KEYSTORE_PASSWORD=changeit
JDK_KEYSTORE_FILE=$JDK_HOME/jre/lib/security/cacerts
CREDHUB_KEYSTORE_PATH=/var/vcap/jobs/credhub/config/cacerts.jks
cp $JDK_KEYSTORE_FILE $CREDHUB_KEYSTORE_PATH

openssl pkcs12 -export -in $CERT_FILE -inkey $PRIVATE_KEY_FILE -out cert.p12 -name $CERT_ALIAS -password pass:k0*l*s3cur1tyr0ck$

$JDK_HOME/bin/keytool -importkeystore \
        -srckeystore cert.p12 -srcstoretype PKCS12 -srcstorepass k0*l*s3cur1tyr0ck$ \
        -deststorepass changeit -destkeypass changeit -destkeystore $CREDHUB_KEYSTORE_PATH \
        -alias $CERT_ALIAS

# remove intermediate files
rm cert.p12 $CERT_FILE $PRIVATE_KEY_FILE

## END CERTIFICATE INSTALLATION