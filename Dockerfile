# ##versions: https://hub.docker.com/r/restic/restic
FROM restic/restic:0.19.1

ARG IMAGE_VERSION=latest

ENV IMAGE_VERSION=${IMAGE_VERSION}
ENV RESTIC_REPOSITORY="/repo"
ENV RESTIC_PASSWORD=""
ENV BACKUP_CRON="00 */24 * * *"
ENV CHECK_CRON="00 04 * * 1"
ENV BACKUP_SOURCE="/data"
ENV RESTIC_FORGET_ARGS="--keep-last 7"
ENV NICE_ADJUST="10"
ENV IONICE_CLASS="2"
ENV IONICE_PRIO="7"
ENV RESTIC_PASSWORD="default_for_tests"
ENV RESTIC_DATA_DIR="/data"
ENV RESTIC_RESTORE="0"
ENV RESTIC_RESTORE_SNAPSHOT="latest"
ENV RESTIC_BACKUP_ON_EXIT="1"
ENV RESTIC_INSTANT_BACKUP="0"
ENV RESTIC_SCRIPTS_DIR="/restic-scripts"
ENV RESTIC_MARKER_FILE_SUBDIR="/"
ENV RESTIC_BACKUP_OPTIONS=""
ENV RESTIC_RESTORE_OPTIONS=""
# writable for any user, so the image also runs as non-root
ENV RESTIC_CACHE_DIR="/tmp/restic-cache"
ENV CRONTAB_FILE="/tmp/crontab"

WORKDIR /

# supercronic instead of busybox crond: it runs as any user (crond needs root).
# Nothing else: hook scripts that need more tools bring their own image.
RUN apk add --no-cache tini supercronic

COPY scripts/* /

ENTRYPOINT ["/sbin/tini", "--", "/entry.sh"]
