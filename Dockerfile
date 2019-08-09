FROM openjdk:8
WORKDIR /app
COPY . /app
RUN ./scripts/setup_dev_mtls.sh
RUN ./gradlew clean bootJar

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
  "-Dspring.config.additional-location=/etc/config/spring.yml,/etc/config/server.yml,/etc/config/security.yml,/etc/config/logging.yml,/etc/config/encryption.yml,/etc/config/auth-server.yml", \
  "-jar", \
  "credhub.jar" \
]
