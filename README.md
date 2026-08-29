# hello-api

A deliberately small Phoenix service for the practice lab. It starts with no secret
configuration and exposes:

- `/` — version and environment JSON
- `/health/live` — BEAM and HTTP process liveness
- `/health/ready` — succeeds unless `DATABASE_URL` is configured and unreachable
- `/metrics` — minimal Prometheus text metrics

`DATABASE_URL` is intentionally optional until Vault and External Secrets deliver a
real environment-scoped database credential. It is never put in a values file or
image layer.

## Local development

```sh
mix deps.get
mix test
mix phx.server
```

The application listens on `4000` by default. Set `PORT`, `APP_ENV`, `APP_VERSION`,
or `DATABASE_URL` only in your local environment or a Kubernetes Secret.

## Repository boundary

This repository owns the Phoenix source, container build, and its one Helm chart in
[`chart/`](chart/). The separate `practice-lab` repository owns Argo CD
ApplicationSets and the staging/production values files that render this chart.
Neither repository stores secret values: Vault is authoritative and workloads consume
Kubernetes Secrets or Vault-injected files.

## Chart checks

```sh
helm lint chart
helm template hello-api chart
go run github.com/norwoodj/helm-docs/cmd/helm-docs@v1.14.2 --chart-search-root=chart
git diff --exit-code -- chart/README.md
```
