#!/bin/bash

set -e

## BEGIN CERTIFICATE INSTALLATION

export JAVA_HOME=/var/vcap/packages/openjdk_1.8.0/jre

CERT_FILE=$1
PRIVATE_KEY_FILE=$2
DATABASE_TLS_CA_FILE=$3
KEYSTORE_PASSWORD=$4

CERT_ALIAS=credhub_tls_cert
JDK_KEYSTORE_FILE=$JAVA_HOME/lib/security/cacerts
CREDHUB_KEYSTORE_PATH=/var/vcap/jobs/credhub/config/cacerts.jks
CREDHUB_DB_TRUST_STORE_PATH=/var/vcap/jobs/credhub/config/db_trust_store.jks
DATABASE_VERIFY_CA_ALIAS=database_verify_ca

cp $JDK_KEYSTORE_FILE $CREDHUB_KEYSTORE_PATH

$JAVA_HOME/bin/keytool -storepasswd -new $KEYSTORE_PASSWORD -keystore $CREDHUB_KEYSTORE_PATH -storepass changeit

if [ -s $CERT_FILE ]; then
    RANDFILE=/etc/sv/monit/.rnd openssl pkcs12 -export -in $CERT_FILE -inkey $PRIVATE_KEY_FILE -out cert.p12 -name $CERT_ALIAS \
            -password pass:k0*l*s3cur1tyr0ck$

    $JAVA_HOME/bin/keytool -importkeystore \
            -srckeystore cert.p12 -srcstoretype PKCS12 -srcstorepass k0*l*s3cur1tyr0ck$ \
            -deststorepass $KEYSTORE_PASSWORD -destkeypass $KEYSTORE_PASSWORD -destkeystore $CREDHUB_KEYSTORE_PATH \
            -alias $CERT_ALIAS
fi

if [ -s $DATABASE_TLS_CA_FILE ]; then
    cp $JDK_KEYSTORE_FILE $CREDHUB_DB_TRUST_STORE_PATH

    $JAVA_HOME/bin/keytool -storepasswd -new $KEYSTORE_PASSWORD -keystore $CREDHUB_DB_TRUST_STORE_PATH -storepass changeit

    $JAVA_HOME/bin/keytool -import -noprompt -keystore $CREDHUB_DB_TRUST_STORE_PATH -storepass $KEYSTORE_PASSWORD \
            -alias $DATABASE_VERIFY_CA_ALIAS -file $DATABASE_TLS_CA_FILE
fi

# remove intermediate files
rm -f cert.p12 $CERT_FILE $PRIVATE_KEY_FILE $DATABASE_TLS_CA_FILE

## END CERTIFICATE INSTALLATION
