# Changelog

## [Unreleased]

## sindri-build 0.11.0

### Changed (breaking: the node needs the three pools first)
- A CI job no longer takes one of the node's two `build-slot`s. It asks for its **cost** in three pools the node
  advertises as extended resources - `clockmost.com/build-memory` (MiB), `build-disk` (GiB), `build-cpu` (millicores) -
  and waits as Pending until all three fit, so many small builds run together and one big build can run alone
  (cm-jnxa). `buildCost` (memory 512Mi, disk 2Gi, cpu 1 by default) is the cost; `buildPool` is the pool sizes the chart
  checks against (5120 MiB / 24 GiB / 8000 m), because a cost above a pool could never be scheduled. Measured on
  2026-11-17: ordinary builds use 60-340 MB and under 1 core, a compile like caddy's bursts to 0.7 GB and 6.6 cores for
  seconds, one felt-llm CUDA build takes ~19 GB of the image volume.
- `buildCost.enforceDisk: true` (the appset sets it when the app declares a disk cost) adds an ephemeral-storage limit
  of 1.25x the disk cost, at least 3Gi, to the `sindri` build container: kubelet evicts only that pod if it overruns,
  and not the node's other pods (what happened to felt-vision on 2026-11-17).
- Roll out only after `install.sh` has put the three pools on the node, or every job waits forever.

## sindri-build 0.10.0

### Added
- `ephemeral.enabled` (default `false`, so every app renders as in 0.9.0): a KEDA ScaledJob replaces the always-on runner
  Deployment and its registration PVC. KEDA polls Shikigami's `GET <queueUrl>/builds/<app>/waiting` and starts one Job per
  waiting job (`maxRunners`, default 1); each Job registers an ephemeral runner (`GITEA_RUNNER_EPHEMERAL`,
  `GITEA_RUNNER_ONCE`), takes one job, unregisters and exits. Registration lives in an emptyDir. Nothing runs while no
  build waits: 55 idle runner pods + PVCs go away once every app is flipped (echo first).

## sindri-build 0.9.0

### Removed
- `sindri` jobs no longer run as `signer` and get no OpenBao token, `BAO_*` env, `/keys` or `DOCKER_CONFIG`: a
  workflow can no longer fetch the app's signing key or Zot login. Releases are meru-release's
  (Meru/meru-release), which runs its own Jobs as `signer`. App workflows still fetching keys fail at that step.
  The `signer` account and the `openbao-ca` ConfigMap stay (meru-release's Jobs use them).

## sindri-build 0.8.2

### Security
- The runner image is gitea/runner 5.3.0 (was 5.2.4), pinned by digest. 5.3.0 fixes GHSA-7c33-wq58-g35r (high: the
  runner's cache shared entries across branches, so a branch writer could poison default-branch builds): cache entries
  are now scoped by ref, so caches start cold once after the upgrade. Also in 5.3.0: `golang.org/x/net` bump for
  CVE-2026-78661 and a Kubernetes job-pod copy mode (`kubernetes.transfer.mode`, off unless configured). Not 5.4.1 or
  6.0.0 on purpose: 6.0.0 removes `builtin:checkout` and needs a workflow check first; 5.4.x adds Windows and other
  features this chart does not need. Existing runners pick it up when each app's chart is synced.

## sindri-build 0.8.1

### Fixed
- A restored app's runner no longer crashloops on a stale `/data/.runner`. Retire deletes the runner's record in Gitea,
  but the `local` volume path is reused on restore, so the old file survived and the daemon died with "unregistered
  runner" on every start (cm-q8ax). The runner now starts through `files/entrypoint.sh`: when the daemon exits with
  that error, the file is removed and the restart registers fresh with the `sindri-registration` token. Every other
  failure leaves it alone. Tested in `scripts/check.sh` with a fake `run.sh`.

## sindri-build 0.8.0

### Added
- `build: false`: a check-only runner for repos that only run their checks (Meru/meru, Meru/nuwa). No `sindri`
  label (ignored if given), no `signer` account, no OpenBao job wiring or CA, no `meru-release` Role. Default `true`:
  every app renders as in 0.7.0. New test case `ci/meru-checks-values.yaml` asserts none of those render.

## sindri-build 0.7.0

### Added
- `meru-release` Role + RoleBinding in every build namespace: Meru/meru-release (namespace `meru-release`) may create,
  read and delete Jobs and read pods there - the app's release Jobs, which run as `signer`. Inert until meru-release
  exists.

## sindri-build 0.6.0

### Added
- A NetworkPolicy for the whole build namespace (`network`, on by default). In: only the node (the kubelet's probes).
  Out: CoreDNS, the host's Caddy (Gitea over HTTPS), OpenBao and Kubernetes API ports, Zot's pods, and public
  addresses. CI jobs run the code of any pull request; they can no longer reach the LAN, the router, other namespaces
  or the host's other ports. `network.enabled: false` turns it off.

## sindri-build 0.5.0

### Changed
- Every CI job pod asks for one `clockmost.com/build-slot`. The node has 2, so at most two jobs run at once across all
  apps and the rest wait as `Pending`. Without the slots on the node, every job waits forever: add them first.

## sindri-build 0.4.0

### Changed
- ESO and the build jobs log in through the shared roles `meru-eso` and `meru-build` instead of
  `meru-<app>-build-eso` / `meru-<app>-build`: OpenBao fills in the namespace from the login, so a new app needs no
  OpenBao setup of its own.
- Build keys are read from the build namespace's own path, `apps/meru/<app>-build/build` (was
  `apps/meru/<app>/build`).

## sindri-build 0.3.0

### Changed
- The runner's `sindri-registration` Secret is filled by the External Secrets Operator from OpenBao
  (`apps/meru/<app>-build/eso/sindri-registration`, role `meru-<app>-build-eso`) and owned by its ExternalSecret,
  no longer made by hand. New: the `eso` ServiceAccount (ESO's login, no pod runs as it), the `openbao`
  SecretStore (wave -2) and the ExternalSecret (wave -1); the Namespace moves to wave -3 so it exists first.
  `openbao.refreshInterval` (default 5m).

## sindri-build 0.2.0

### Changed
- `sindri` jobs fetch the app's Zot login and signing key from OpenBao instead of mounted Secrets: they run as the
  new `signer` account with a 10-minute token meant only for OpenBao (audience `openbao`), get `BAO_ADDR`,
  `BAO_CACERT`, `BAO_ROLE`, `BAO_KEYS_PATH`, `BAO_JWT_FILE`, and an in-memory `/keys` for what they fetch
  (`DOCKER_CONFIG=/keys/zot`). The app's build workflow does the fetch. The `<app>-builder-zot` and `<app>-cosign`
  Secrets are no longer used.

### Added
- `openbao.addr`, `openbao.caCert` (the `openbao-ca` ConfigMap).

## sindri-build 0.1.0

### Added
- The build namespace for one app: `<app>-build` with the Gitea runner `sindri-<app>` (gitea/runner 5.2.4), its
  role, its registration volume and its config.
- Job pods start "restricted" with no credentials; only `sindri`-label jobs get rootless BuildKit, the registry login
  and the signing key.
- `labels`: extra runner labels for check jobs.
