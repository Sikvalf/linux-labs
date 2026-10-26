# syntax=docker/dockerfile:1.7
#
# Multi-stage сборка Spring Boot приложения:
#   1) builder — собирает jar Maven'ом и раскладывает его на слои;
#   2) runtime — только JRE на Alpine + слои приложения, запуск от non-root.

ARG BUILDER_IMAGE=maven:3.9.11-eclipse-temurin-21
ARG RUNTIME_IMAGE=eclipse-temurin:21.0.8_9-jre-alpine

############################
# Stage 1: builder
############################
FROM ${BUILDER_IMAGE} AS builder
WORKDIR /build

# Сначала только pom.xml: слой с зависимостями кэшируется и не пересобирается,
# пока не поменялись зависимости (меняется только код -> быстрая пересборка).
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -B -q dependency:go-offline

COPY src ./src
# Собираем fat-jar и раскладываем его на слои (dependencies / spring-boot-loader /
# snapshot-dependencies / application), чтобы в runtime-образе
# редко меняющиеся зависимости лежали в отдельном кэшируемом слое.
RUN --mount=type=cache,target=/root/.m2 mvn -B -q package -DskipTests \
 && cp target/app.jar application.jar \
 && java -Djarmode=tools -jar application.jar extract --layers --destination extracted

############################
# Stage 2: runtime
############################
FROM ${RUNTIME_IMAGE} AS runtime

ARG APP_VERSION=1.0.0
LABEL org.opencontainers.image.title="lab2-app" \
      org.opencontainers.image.description="Spring Boot app with /health endpoint (DevOps lab 2)" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.authors="Kiselev Valery"

# Непривилегированный пользователь с фиксированными UID/GID
RUN addgroup -S -g 10001 app \
 && adduser -S -D -H -u 10001 -G app -s /sbin/nologin app

WORKDIR /app

# Слои копируются от редко меняющихся к часто меняющимся
COPY --from=builder --chown=app:app /build/extracted/dependencies/ ./
COPY --from=builder --chown=app:app /build/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=app:app /build/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=app:app /build/extracted/application/ ./

# JAVA_TOOL_OPTIONS JVM читает сама — так ENTRYPOINT остаётся в exec-форме
ENV SERVER_PORT=8080 \
    APP_VERSION=${APP_VERSION} \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/./urandom"

EXPOSE 8080

USER 10001:10001

HEALTHCHECK --interval=15s --timeout=3s --start-period=40s --retries=3 \
  CMD ["wget", "-q", "--spider", "http://127.0.0.1:8080/health"]

ENTRYPOINT ["java", "-jar", "/app/application.jar"]
