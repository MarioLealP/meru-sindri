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


echo "== meru-checks: no build label, no signer, no OpenBao, no release Role"
for unwanted in 'name: signer' 'serviceAccountName: signer' 'BAO_' 'name: openbao-ca' 'name: meru-release' 'sindri:kubernetes://'; do
  if grep -qF -- "$unwanted" out/meru-checks.yaml; then
    echo "meru-checks: '$unwanted' rendered in a check-only runner" >&2
    exit 1
  fi
done
grep -qF 'sindri-check:kubernetes://' out/meru-checks.yaml || { echo "meru-checks: no sindri-check label" >&2; exit 1; }
