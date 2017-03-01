#!/bin/bash

set -e

## BEGIN CERTIFICATE INSTALLATION

export JAVA_HOME=/var/vcap/packages/openjdk_1.8.0/jre

CERT_FILE=/var/vcap/jobs/credhub/config/cert.crt
PRIVATE_KEY_FILE=/var/vcap/jobs/credhub/config/priv.key
DATABASE_TLS_CA_FILE=/var/vcap/jobs/credhub/config/database_ca.crt
KEY_STORE_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)

CERT_ALIAS=credhub_tls_cert
CREDHUB_KEY_STORE_PATH=/var/vcap/jobs/credhub/config/cacerts.jks
CREDHUB_DB_TRUST_STORE_PATH=/var/vcap/jobs/credhub/config/db_trust_store.jks
DATABASE_VERIFY_CA_ALIAS=database_verify_ca

sed -i "s/KEY_STORE_PASSWORD_PLACEHOLDER/${KEY_STORE_PASSWORD}/g" /var/vcap/jobs/credhub/config/application.yml

rm -f $CERT_FILE $PRIV_KEY_FILE $DATABASE_CA_CERT

cat > $CERT_FILE <<EOL
<%= p('credhub.tls.certificate') %>
EOL

cat > $PRIV_KEY_FILE <<EOL
<%= p('credhub.tls.private_key') %>
EOL

<% if_p('credhub.data_storage.tls_ca') do |tls_ca| %>

cat > $DATABASE_CA_CERT <<EOL
<%= tls_ca %>
EOL

<% end %>

if [ -s $CERT_FILE ]; then
    RANDFILE=/etc/sv/monit/.rnd openssl pkcs12 -export -in $CERT_FILE -inkey $PRIVATE_KEY_FILE -out cert.p12 -name $CERT_ALIAS \
            -password pass:k0*l*s3cur1tyr0ck$

    $JAVA_HOME/bin/keytool -importkeystore \
            -srckeystore cert.p12 -srcstoretype PKCS12 -srcstorepass k0*l*s3cur1tyr0ck$ \
            -deststorepass $KEY_STORE_PASSWORD -destkeypass $KEY_STORE_PASSWORD -destkeystore $CREDHUB_KEY_STORE_PATH \
            -alias $CERT_ALIAS
fi

if [ -s $DATABASE_TLS_CA_FILE ]; then
    $JAVA_HOME/bin/keytool -import -noprompt -keystore $CREDHUB_DB_TRUST_STORE_PATH -storepass $KEY_STORE_PASSWORD \
            -alias $DATABASE_VERIFY_CA_ALIAS -file $DATABASE_TLS_CA_FILE
fi

# remove intermediate files
rm -f cert.p12 $CERT_FILE $PRIVATE_KEY_FILE $DATABASE_TLS_CA_FILE

## END CERTIFICATE INSTALLATION
