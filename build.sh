#!/bin/bash
docker build --build-arg BUILD_TIME="$(date '+%Y-%m-%d %H:%M:%S')" -t hub.cangling.cn/cangling/cuda-dev:1.0 -f ./Dockerfile .
