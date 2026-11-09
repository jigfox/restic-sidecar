#!/usr/bin/env bash

# local image, see `mise run docker:build`
IMG=${IMG:-ghcr.io/jigfox/restic-sidecar:latest}

docker run -it --rm --name restic --hostname restic-test \
    -p 8002:8001 \
    -v "$PWD"/testrepo:/repo \
    -v "$PWD"/testdata:/data \
    "$IMG"
