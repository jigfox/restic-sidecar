#!/usr/bin/env bash

. ./VERSION

docker run -it --rm --hostname restic-test \
    -e RESTIC_RESTORE=1 \
    -v $(pwd)/testrepo:/repo \
    -v $(pwd)/testdata:/data \
    -v $(pwd)/testscripts:/restic-scripts \
    ${REGISTRY_NAME}/${IMAGE_NAME}:latest
