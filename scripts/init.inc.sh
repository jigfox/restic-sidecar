# shellcheck shell=sh

# Defaults. Unset or empty variables get one (":="; the restic base image
# itself sets IONICE_CLASS to ""), except the argument lists below, where ""
# is meaningful (RESTIC_FORGET_ARGS="" disables forget).
: "${RESTIC_REPOSITORY:=/repo}"
: "${BACKUP_SOURCE:=/data}"
: "${BACKUP_CRON:=00 */24 * * *}"
: "${CHECK_CRON:=00 04 * * 1}"
: "${RESTIC_FORGET_ARGS=--keep-last 7}"
: "${RESTIC_BACKUP_OPTIONS=}"
: "${RESTIC_RESTORE_OPTIONS=}"
: "${RESTIC_RESTORE:=0}"
: "${RESTIC_RESTORE_SNAPSHOT:=latest}"
: "${RESTIC_INSTANT_BACKUP:=0}"
: "${RESTIC_BACKUP_ON_EXIT:=1}"
: "${RESTIC_DATA_DIR:=/data}"
: "${RESTIC_MARKER_FILE_SUBDIR:=/}"
: "${RESTIC_SCRIPTS_DIR:=/restic-scripts}"
# writable for any user, so the image also runs as non-root
: "${RESTIC_CACHE_DIR:=/tmp/restic-cache}"
: "${CRONTAB_FILE:=/tmp/crontab}"
: "${NICE_ADJUST:=10}"
: "${IONICE_CLASS:=2}"
: "${IONICE_PRIO:=7}"
: "${IMAGE_VERSION:=unknown}"
RESTIC_HOST=${RESTIC_HOST:-localhost}
# restic reads some of these itself, hook scripts may use the others
export RESTIC_REPOSITORY BACKUP_SOURCE BACKUP_CRON CHECK_CRON RESTIC_FORGET_ARGS \
  RESTIC_BACKUP_OPTIONS RESTIC_RESTORE_OPTIONS RESTIC_RESTORE RESTIC_RESTORE_SNAPSHOT \
  RESTIC_INSTANT_BACKUP RESTIC_BACKUP_ON_EXIT RESTIC_DATA_DIR RESTIC_MARKER_FILE_SUBDIR \
  RESTIC_SCRIPTS_DIR RESTIC_CACHE_DIR CRONTAB_FILE NICE_ADJUST IONICE_CLASS IONICE_PRIO \
  IMAGE_VERSION RESTIC_HOST

# There is no default password: a forgotten one must not silently create or
# open a repository protected by a well-known password.
if [ -z "${RESTIC_PASSWORD:-}${RESTIC_PASSWORD_FILE:-}${RESTIC_PASSWORD_COMMAND:-}" ]; then
  echo "ERROR: no repository password; set RESTIC_PASSWORD, RESTIC_PASSWORD_FILE or RESTIC_PASSWORD_COMMAND" >&2
  exit 1
fi

RESTORED_MARKER_FILE=${RESTIC_DATA_DIR}${RESTIC_MARKER_FILE_SUBDIR}restic-restored.txt
RESTORE_IN_PROGRESS_MARKER_FILENAME=restic-restore-inprogress.txt
RESTORE_IN_PROGRESS_MARKER_FILE=${RESTIC_DATA_DIR}${RESTIC_MARKER_FILE_SUBDIR}${RESTORE_IN_PROGRESS_MARKER_FILENAME}

RESTORED_TXT="
  The presents of this file shows, that this volume was initialy restored.
  Removing this file leads to a full restore on the next container start."

RESTORE_IN_PROGRESS_TXT="
  The presents of this file shows, that the restore process is currently running.
  Remove this file only if something went wrong during restore."


markRestored() {
  echo "${RESTORED_TXT}" > ${RESTORED_MARKER_FILE}
}

markRestoreInProgress() {
  echo "${RESTORE_IN_PROGRESS_TXT}" > ${RESTORE_IN_PROGRESS_MARKER_FILE}
}

unmarkRestoreInProgress() {
  if [ -f ${RESTORE_IN_PROGRESS_MARKER_FILE} ]; then
    rm ${RESTORE_IN_PROGRESS_MARKER_FILE}
  fi
}

waitForRestoreCompletedAndExit() {
  if [ -f ${RESTORE_IN_PROGRESS_MARKER_FILE} ]; then
    echo "Restore already in progress."
    while [ -f ${RESTORE_IN_PROGRESS_MARKER_FILE} ]; do
      echo "Waiting for completion ..."
      sleep 5
    done
    echo "Restore completed. Exit now."
    exit 0
  fi
}

waitForRestoreCompleted() {
  if [ -f ${RESTORE_IN_PROGRESS_MARKER_FILE} ]; then
    echo "Restore already in progress."
    while [ -f ${RESTORE_IN_PROGRESS_MARKER_FILE} ]; do
      echo "Waiting for completion ..."
      sleep 5
    done
    echo "Restore completed."
  fi
}

runScripts() {
  SUB_DIR=${1}
  if [ -z "${SUB_DIR}" ]; then
    echo "No sub directory given. Exiting."
    exit 1
  fi

  # Define the directory containing the scripts
  DIR="${RESTIC_SCRIPTS_DIR}/${SUB_DIR}"


  # Check if the directory exists
  if [ -d "${DIR}" ]; then
      echo "Running scripts from ${DIR}"

      # Change to the directory
      cd "${DIR}" || return 1

      # Loop over each script in the directory (the glob stays literal when the
      # directory is empty, so guard with a file test)
      for FILE in *.sh
      do
          [ -f ${FILE} ] || continue
          echo "Running ${FILE}"
          sh ./"${FILE}"
      done
  fi

}
