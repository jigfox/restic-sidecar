#!/usr/bin/env bash

# local image, see `mise run docker:build`
IMG=${IMG:-ghcr.io/jigfox/restic-sidecar:latest}

docker run -it --rm --name restic --hostname restic-test \
    --entrypoint /bin/sh \
    -v "$PWD"/testrepo:/repo \
    -v "$PWD"/testdata:/data \
    -v "$PWD"/testscripts:/restic-scripts \
    "$IMG"
