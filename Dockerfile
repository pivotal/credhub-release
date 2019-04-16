FROM openjdk:8
WORKDIR /app
COPY src/credhub /app
#ENV CREDHUB_SERVER_VERSION=2.2.1-dev
RUN ./gradlew bootJar

FROM openjdk:8-jre-alpine
WORKDIR /app
COPY --from=0 /app/applications/credhub-api/build/libs/credhub.jar .
CMD ["java", "-jar", "/app/credhub.jar"]
