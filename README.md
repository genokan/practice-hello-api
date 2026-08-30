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

## Failure lab

The staging-only failure-lab design, including environment-specific replica
behaviour,
controlled in-app faults, k6 profiles, and Grafana observability, is documented
in [docs/failure-lab-plan.md](docs/failure-lab-plan.md).

## Run a staging load profile

When staging enables the chart's load templates, Argo creates three **suspended**
CronJobs. They never schedule a test by themselves. Start a fresh, manually named
Job with normal Kubernetes commands:

```sh
kubectl -n hello-staging create job \
  --from=cronjob/hello-api-load-smoke \
  hello-api-load-smoke-01
kubectl -n hello-staging logs -f job/hello-api-load-smoke-01
```

- `smoke`: two virtual users for 30 seconds; deployment verification.
- `spike`: ramps to 20 virtual users for a short failure exercise.
- `sustained`: eight virtual users for five minutes; latency and memory trends.

Replace `smoke` in both command positions with `spike` or `sustained`. The
profiles target the in-cluster Service (`/work`), so they measure the application
and its Kubernetes Service rather than DNS, Caddy, Traefik, or TLS. They are
staging-only and have no production templates.
