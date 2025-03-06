#!/bin/sh

# Debian Slim image with JDK
docker build --no-cache . -f Dockerfile.debian-slim-jar -t webserver:debian-slim.jar