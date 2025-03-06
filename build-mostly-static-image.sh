#!/bin/sh

# For local building
# Compile linking zlib and JDK shared libraries except the standard C library (libc); optimize for size
# ./mvnw -Dmaven.test.skip=true -Pnative,mostly-static native:compile

# Distroless Base (provides glibc)
docker build --no-cache . -f Dockerfile.distroless-base.mostly -t webserver:distroless-base.mostly-static