#!/usr/bin/env bash

# local image, see `mise run docker:build`
IMG=${IMG:-ghcr.io/jigfox/restic-sidecar:latest}

docker run -it --rm --name restic --hostname restic-test \
    -e RESTIC_PASSWORD="${RESTIC_PASSWORD:-local-test}" \
    --entrypoint /bin/sh \
    -v "$PWD"/testrepo:/repo \
    -v "$PWD"/testdata:/data \
    -v "$PWD"/testscripts:/restic-scripts \
    "$IMG"
