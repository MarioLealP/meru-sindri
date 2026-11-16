#!/usr/bin/env bash
# The image's run.sh, plus one repair. A registration (/data/.runner) outlives its runner record in Gitea when the
# app is retired and restored: the `local` volume path is reused (the app's data comes back), but the record was
# deleted at retire. The daemon then dies with "unregistered runner" on every start and a new token never helps,
# because run.sh only registers when the file is missing. So: when the daemon says that, drop the file and exit -
# the restart registers fresh with the token from sindri-registration.
set -u
runner_file="${RUNNER_STATE_FILE:-/data/.runner}"
seen="$(mktemp)"

# Keep the daemon's output as is; only note whether the server refused our registration.
run.sh > >(tee >(grep -F 'unregistered runner' >"$seen")) 2>&1 &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null' TERM INT # a running job gets terminationGracePeriodSeconds to finish
wait "$pid"
rc=$?
if kill -0 "$pid" 2>/dev/null; then # our trap ended the wait, not the daemon: wait for it for real
  wait "$pid"
  rc=$?
fi
trap - TERM INT
sleep 0.2 # let the log filter flush

if [[ $rc -ne 0 && -s $seen ]]; then
  echo "sindri: Gitea does not know this runner (stale $runner_file); removing it so the restart registers anew"
  rm -f -- "$runner_file"
fi
exit "$rc"
