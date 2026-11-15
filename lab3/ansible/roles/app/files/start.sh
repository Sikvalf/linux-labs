#!/bin/sh
set -eu

cd /opt/lab3-app

export SERVER_PORT="${SERVER_PORT:-8080}"

exec java ${JAVA_OPTS:-} -jar /opt/lab3-app/app.jar
