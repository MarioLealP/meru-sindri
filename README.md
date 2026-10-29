# Sindri

The build side of **Meru**, a small in-house container platform (CaaS) on k3s. Sindri holds `sindri-build`, the Helm
chart that gives one Meru app its build namespace: a [Gitea runner](https://gitea.com/gitea/runner) registered to that
app's repo only, which runs every CI job as its own pod.

What the chart builds for an app `<app>`:

- the namespace `<app>-build`, apart from the running app's `<app>` - code from a pull request runs here, never next
  to the app's own identity and data
- the runner (`sindri-<app>`): Pod Security "restricted", read-only root filesystem, allowed to create and delete job
  pods in its own namespace and nothing else
- job pods that start with nothing: a plain user, no capabilities, no service account token, no credentials
- for jobs on the `sindri` label only: rootless BuildKit (SELinux `container_engine_t`, a seccomp profile with user
  namespaces, `SETUID`/`SETGID` for `newuidmap`), and a 10-minute token of the `signer` account that only OpenBao
  accepts - the job trades it for the app's registry login and signing key, kept in memory
- Meru's CMDB labels on every resource and pod

## Usage

Values for an app, the minimum:

```yaml
app: echo
owner: mario
```

More labels for jobs that run the PR's code (tests, linters) with nothing to steal:

```yaml
labels:
  sindri-check: ghcr.io/astral-sh/uv@sha256:<digest>
```

`charts/sindri-build/values.yaml` documents each option and `charts/sindri-build/values.schema.json` rejects unknown
keys. In Meru, Argo CD renders the chart for each app; nothing runs `helm install`. Per app, three credentials are made
outside the chart: the runner's registration token (`sindri-registration`), and in OpenBao (`apps/meru/<app>/build`,
login role `meru-<app>-build`) the registry login and the signing key.

A build step fetches the keys with the build image's busybox `wget` (the values are base64, so `sed` can take them
out of the JSON):

```sh
login=$(printf '{"role":"%s","jwt":"%s"}' "$BAO_ROLE" "$(cat "$BAO_JWT_FILE")")
token=$(SSL_CERT_FILE=$BAO_CACERT wget -q -O- --post-data "$login" "$BAO_ADDR/v1/auth/kubernetes/login" |
  sed -n 's/.*"client_token":"\([^"]*\)".*/\1/p')
keys=$(SSL_CERT_FILE=$BAO_CACERT wget -q -O- --header "X-Vault-Token: $token" "$BAO_ADDR/v1/$BAO_KEYS_PATH")
field() { printf '%s' "$keys" | sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" | base64 -d; }
```

## Development

Prerequisites: `helm` 4, `kubeconform`, and optionally the Kyverno CLI with a checkout of Meru's policies.

```sh
scripts/check.sh                                            # lint + render every ci/*-values.yaml + schema-validate
scripts/check.sh ../clockmost-infra/k8s/kyverno-policies    # ... and run Meru's admission rules on the output
```

Each `charts/sindri-build/ci/*-values.yaml` is a test case. Commits follow Conventional Commits; changes go in through
pull requests to `main`.

## License

MIT - see `LICENSE`.
