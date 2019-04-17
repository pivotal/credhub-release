FROM openjdk:8
WORKDIR /app
COPY . /app
RUN ./gradlew clean downloadBouncyCastleFips bootJar
RUN ./scripts/setup_dev_mtls.sh
# TODO: we shouldn't need the :downloadBouncyCastleFips above :(

FROM openjdk:8-jre-alpine
WORKDIR /app
COPY \
  --from=0 \
  /app/applications/credhub-api/build/libs/credhub.jar \
  .
COPY \
  --from=0 \
  /app/applications/credhub-api/src/main/resources/log4j2.properties \
  .
COPY \
  --from=0 \
  /app/applications/credhub-api/src/test/resources/auth_server_trust_store.jks \
  .
COPY \
  --from=0 \
  /app/applications/credhub-api/src/test/resources/key_store.jks \
  .
COPY \
  --from=0 \
  /app/applications/credhub-api/src/test/resources/trust_store.jks \
  .
EXPOSE 9000
CMD [ \
  "java", \
  "-Dspring.profiles.active=dev,dev-h2", \
  "-Dlogging.config=log4j2.properties", \
  "-Dauth-server.trust_store=auth_server_trust_store.jks", \
  "-Dserver.ssl.key_store=key_store.jks", \
  "-Dserver.ssl.trust_store=trust_store.jks", \
  "-jar", \
  "credhub.jar" \
]
