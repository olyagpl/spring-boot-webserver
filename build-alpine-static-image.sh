#!/bin/sh

# For local building
# SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# TOOLCHAIN_DIR=${SCRIPT_DIR}/musl-toolchain
# PATH=${TOOLCHAIN_DIR}/bin:${PATH}

# Create a statically linked binary that can be used without any additional library dependencies; optimize for size
# ./mvnw -Dmaven.test.skip=true -Pnative,fully-static native:compile

docker build --no-cache . -f Dockerfile.alpine.static -t webserver:scratch.static-alpine