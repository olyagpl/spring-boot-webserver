#!/bin/sh

# For local building
# rm -f target/webserver.static-upx

# Compress with UPX
# ./upx --lzma --best -o target/webserver.static-upx target/webserver.static

# Scratch--fully static and compressed
docker build --no-cache . -f Dockerfile.scratch.static-upx -t webserver:scratch.static-upx