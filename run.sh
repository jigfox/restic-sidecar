#!/usr/bin/env bash

. ./VERSION

docker run -it --rm --name restic --hostname restic-test \
    -p 8002:8001 \
    -v $(pwd)/testrepo:/repo \
    -v $(pwd)/testdata:/data \
    ${REGISTRY_NAME}/${IMAGE_NAME}:latest
