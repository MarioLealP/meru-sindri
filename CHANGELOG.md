# Changelog

## [Unreleased]

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
