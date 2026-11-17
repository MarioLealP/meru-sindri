#!/bin/bash
# Lint and render the chart with every ci/*-values.yaml and validate the output against the Kubernetes schemas.
# Usage: scripts/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."
chart=charts/sindri-build
rm -rf out && mkdir -p out

for values in "$chart"/ci/*-values.yaml; do
  case_name="$(basename "$values" -values.yaml)"
  echo "== $case_name"
  helm lint --strict "$chart" -f "$values" --quiet
  helm template "$case_name" "$chart" -n test -f "$values" >"out/$case_name.yaml"
  kubeconform -strict -summary -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
    "out/$case_name.yaml"
done


echo "== budget: a job asks for its cost in all three pools; a declared disk cost is enforced; a cost above a pool is refused"
for want in 'clockmost.com/build-memory: 512' 'clockmost.com/build-disk: 2' 'clockmost.com/build-cpu: 1000'; do
  grep -qF -- "$want" out/echo.yaml || { echo "echo: default cost '$want' not rendered" >&2; exit 1; }
done
grep -qF 'build-slot' out/echo.yaml && { echo "echo: the old build-slot is still requested" >&2; exit 1; }
grep -qF 'ephemeral-storage' out/echo.yaml && { echo "echo: ephemeral-storage limited without a declared disk cost" >&2; exit 1; }
for want in 'clockmost.com/build-memory: 4096' 'clockmost.com/build-disk: 20' 'clockmost.com/build-cpu: 4000' 'ephemeral-storage: 25Gi'; do
  grep -qF -- "$want" out/budget.yaml || { echo "budget: '$want' not rendered" >&2; exit 1; }
done
for over in buildCost.memory=6Gi buildCost.disk=25Gi buildCost.cpu=9; do
  if helm template over "$chart" -n test -f "$chart/ci/echo-values.yaml" --set "$over" >/dev/null 2>&1; then
    echo "budget: $over is above a pool but the chart rendered it" >&2; exit 1
  fi
done

echo "== meru-checks: no build label, no signer, no OpenBao, no release Role"
for unwanted in 'name: signer' 'serviceAccountName: signer' 'BAO_' 'name: openbao-ca' 'name: meru-release' 'sindri:kubernetes://'; do
  if grep -qF -- "$unwanted" out/meru-checks.yaml; then
    echo "meru-checks: '$unwanted' rendered in a check-only runner" >&2
    exit 1
  fi
done
grep -qF 'sindri-check:kubernetes://' out/meru-checks.yaml || { echo "meru-checks: no sindri-check label" >&2; exit 1; }

echo "== entrypoint: a stale registration is dropped, a healthy one is kept"
shellcheck charts/sindri-build/files/entrypoint.sh
grep -qF 'entrypoint.sh' out/echo.yaml || { echo "echo: entrypoint.sh not rendered" >&2; exit 1; }
grep -qF 'bash, /config/entrypoint.sh' out/echo.yaml || { echo "echo: runner not started through entrypoint.sh" >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
cat >"$work/bin/run.sh" <<'FAKE' # stands in for the image's run.sh: prints $FAKE_LOG and exits with $FAKE_RC
#!/usr/bin/env bash
echo "$FAKE_LOG"
exit "$FAKE_RC"
FAKE
chmod +x "$work/bin/run.sh"
run_entrypoint() { # log, exit code -> the entrypoint's exit code
  echo '{"id":4}' >"$work/.runner"
  FAKE_LOG="$1" FAKE_RC="$2" RUNNER_STATE_FILE="$work/.runner" PATH="$work/bin:$PATH" \
    bash charts/sindri-build/files/entrypoint.sh >/dev/null && return 0 || return $?
}
rc=0; run_entrypoint 'level=error msg="unregistered runner"' 1 || rc=$?
[ "$rc" = 1 ] && [ ! -e "$work/.runner" ] || { echo "entrypoint: stale .runner kept (rc=$rc)" >&2; exit 1; }
rc=0; run_entrypoint 'level=error msg="gitea unreachable"' 1 || rc=$?
[ "$rc" = 1 ] && [ -e "$work/.runner" ] || { echo "entrypoint: .runner removed for another failure (rc=$rc)" >&2; exit 1; }
rc=0; run_entrypoint 'unregistered runner (but the daemon exited cleanly)' 0 || rc=$?
[ "$rc" = 0 ] && [ -e "$work/.runner" ] || { echo "entrypoint: .runner removed after a clean exit (rc=$rc)" >&2; exit 1; }
