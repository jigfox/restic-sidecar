#!/usr/bin/env bash
# Smoke tests against a built image (IMG, default restic-sidecar:dev):
# startup checks, backup with hooks, snapshots, check, forget, restore and
# cron mode with the backup on SIGTERM. Each test uses a fresh repository in a
# temporary directory below test/ (Docker Desktop and colima only share $HOME).
set -euo pipefail

IMG=${IMG:-restic-sidecar:dev}
cd "$(dirname "$0")"
HOOKS=$PWD/hooks
PASSWORD=smoke-test
failures=0

tmp=$(mktemp -d "$PWD/tmp.XXXXXX")
container=restic-smoke-$$
cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  # the container writes as root: on Linux only root may delete it again
  docker run --rm -v "$tmp:/t" --entrypoint sh "$IMG" -c 'rm -rf /t/*' >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

pass() { echo "ok   $1"; }
fail() {
  echo "FAIL $1"
  [ -n "${2:-}" ] && sed 's/^/     | /' <<<"$2"
  failures=$((failures + 1))
}

# fresh repo and data dirs in a new directory (never deleted before the end:
# on Linux the container's root-owned files can't be removed by the caller)
fresh() {
  dir=$(mktemp -d "$tmp/case.XXXXXX")
  mkdir -p "$dir/repo" "$dir/data" "$dir/restore"
  echo "hello" >"$dir/data/file.txt"
  chmod -R a+rwX "$dir"
}

# sidecar <data dir> [docker args...] [-- command...] -> output; exit code in $rc
sidecar() {
  local data=$1
  shift
  local opts=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do
    opts+=("$1")
    shift
  done
  [ $# -gt 0 ] && shift
  rc=0
  out=$(docker run --rm -v "$dir/repo:/repo" -v "$data:/data" -v "$HOOKS:/restic-scripts:ro" \
    ${opts[@]+"${opts[@]}"} "$IMG" "$@" 2>&1) || rc=$?
}

backup() { sidecar "$dir/data" -e RESTIC_PASSWORD=$PASSWORD -e RESTIC_INSTANT_BACKUP=1 -e RESTIC_BACKUP_ON_EXIT=0 "$@"; }

t="no password: exits 1 with an error"
fresh
sidecar "$dir/data"
if [ "$rc" = 1 ] && grep -q "ERROR: no repository password" <<<"$out"; then pass "$t"; else fail "$t (exit $rc)" "$out"; fi

t="instant backup: initializes the repository, runs the hooks, saves a snapshot"
backup
if [ "$rc" = 0 ] && grep -q "Initializing restic repository" <<<"$out" &&
  grep -q "Hello pre backup" <<<"$out" && grep -qE "snapshot [0-9a-f]+ saved" <<<"$out" &&
  grep -q "Hello post backup" <<<"$out"; then pass "$t"; else fail "$t (exit $rc)" "$out"; fi

t="forget runs with the default RESTIC_FORGET_ARGS"
if grep -q "Applying Policy: keep 7 latest snapshots" <<<"$out"; then pass "$t"; else fail "$t" "$out"; fi

t="empty RESTIC_FORGET_ARGS: no forget"
backup -e RESTIC_FORGET_ARGS=
if [ "$rc" = 0 ] && ! grep -q "Applying Policy" <<<"$out"; then pass "$t"; else fail "$t (exit $rc)" "$out"; fi

t="snapshots.sh lists both snapshots, check.sh finds no errors"
sidecar "$dir/data" -e RESTIC_PASSWORD=$PASSWORD --entrypoint sh -- -c './snapshots.sh && ./check.sh'
if [ "$rc" = 0 ] && grep -q "^2 snapshots" <<<"$out" && grep -q "no errors were found" <<<"$out"; then
  pass "$t"
else fail "$t (exit $rc)" "$out"; fi

t="wrong password: exits 1, the repository is not re-initialized"
sidecar "$dir/data" -e RESTIC_PASSWORD=wrong -e RESTIC_INSTANT_BACKUP=1 -e RESTIC_BACKUP_ON_EXIT=0
if [ "$rc" = 1 ] && grep -q "is not accessible" <<<"$out" && ! grep -q "Initializing" <<<"$out"; then
  pass "$t"
else fail "$t (exit $rc)" "$out"; fi

t="restore: fills an empty volume and writes the marker"
sidecar "$dir/restore" -e RESTIC_PASSWORD=$PASSWORD -e RESTIC_RESTORE=1
if [ "$rc" = 0 ] && [ "$(cat "$dir/restore/file.txt" 2>/dev/null)" = hello ] &&
  [ -f "$dir/restore/restic-restored.txt" ] && grep -q "Hello pre restore" <<<"$out" &&
  grep -q "Hello post restore" <<<"$out"; then pass "$t"; else fail "$t (exit $rc)" "$out"; fi

t="restore: skipped when the marker is present"
sidecar "$dir/restore" -e RESTIC_PASSWORD=$PASSWORD -e RESTIC_RESTORE=1
if [ "$rc" = 0 ] && grep -q "is present -> skip restore" <<<"$out"; then pass "$t"; else fail "$t (exit $rc)" "$out"; fi

t="restore from a missing repository: starts empty and marks the volume"
fresh
sidecar "$dir/restore" -e RESTIC_PASSWORD=$PASSWORD -e RESTIC_RESTORE=1
if [ "$rc" = 0 ] && grep -q "does not exists, assuming starting from scratch" <<<"$out" &&
  [ -f "$dir/restore/restic-restored.txt" ]; then pass "$t"; else fail "$t (exit $rc)" "$out"; fi

t="cron mode as non-root: crontab accepted, backup on SIGTERM"
fresh
# the repository on a tmpfs: bind mounts are not writable for uid 1000 on
# every Docker host (colima), and it only has to live as long as the container
docker run -d --name "$container" -u 1000:1000 --tmpfs /repo:mode=1777 -v "$dir/data:/data:ro" \
  -e RESTIC_PASSWORD=$PASSWORD "$IMG" >/dev/null
for _ in $(seq 1 30); do
  docker logs "$container" 2>&1 | grep -q "read crontab" && break
  sleep 1
done
docker stop -t 60 "$container" >/dev/null
out=$(docker logs "$container" 2>&1)
if grep -q "Container setup complete" <<<"$out" && grep -q "read crontab" <<<"$out" &&
  ! grep -q "level=fatal" <<<"$out" && grep -q "backup on exit" <<<"$out" &&
  grep -qE "snapshot [0-9a-f]+ saved" <<<"$out"; then pass "$t"; else fail "$t" "$out"; fi

echo
if [ "$failures" = 0 ]; then
  echo "all smoke tests passed"
else
  echo "$failures smoke test(s) failed"
  exit 1
fi
