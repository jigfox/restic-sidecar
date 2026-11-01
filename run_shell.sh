#!/usr/bin/env bash

. ./VERSION

docker run -it --rm --name restic --hostname restic-test \
    --entrypoint /bin/sh \
    -v $(pwd)/testrepo:/repo \
    -v $(pwd)/testdata:/data \
    -v $(pwd)/testscripts:/restic-scripts \
    ${REGISTRY_NAME}/${IMAGE_NAME}:latest
