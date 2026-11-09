# ##versions: https://hub.docker.com/r/restic/restic
FROM restic/restic:0.19.1

ARG IMAGE_VERSION=latest
# every other default lives in scripts/init.inc.sh
ENV IMAGE_VERSION=${IMAGE_VERSION}

WORKDIR /

# supercronic instead of busybox crond: it runs as any user (crond needs root).
# Nothing else: hook scripts that need more tools bring their own image.
RUN apk add --no-cache tini supercronic

COPY scripts/* /

ENTRYPOINT ["/sbin/tini", "--", "/entry.sh"]
