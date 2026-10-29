# Changelog

## [Unreleased]

## sindri-build 0.1.0

### Added
- The build namespace for one app: `<app>-build` with the Gitea runner `sindri-<app>` (gitea/runner 5.2.4), its
  role, its registration volume and its config.
- Job pods start "restricted" with no credentials; only `sindri`-label jobs get rootless BuildKit, the registry login
  and the signing key.
- `labels`: extra runner labels for check jobs.
