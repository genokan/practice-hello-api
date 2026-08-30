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

The staging-only failure-lab lets you create small, bounded failure scenarios
and observe their Kubernetes, Prometheus, Grafana, and Loki signals. Its broader
design and an explicit built-versus-planned status are in
[docs/failure-lab-plan.md](docs/failure-lab-plan.md).

### Use the live UI

Open [hello-staging.opsguy.io/lab](https://hello-staging.opsguy.io/lab). This is
the actual control page, not a mockup. It is enabled only in staging; the same
paths return `404` in production.

The page shows the pod that handled the request and exposes these controls:

| Control | What it changes | What to observe |
| --- | --- | --- |
| Latency | Adds a bounded delay to `/work` requests handled by that pod | p95 latency and k6 request duration |
| Errors | Makes a selected percentage of that pod's `/work` requests return `503` | 5xx rate and application logs |
| Readiness | Makes that pod's readiness probe fail while its process remains live | Service endpoints and available pods |
| Reset | Immediately removes the active scenario from that pod | The active-mode dashboard panel returns to idle |

Every scenario has a 1–300 second expiry. The controls are deliberately
pod-local: with two staging replicas, a partial failure and load balancing are
part of the exercise. If the browser is routed to the other pod, reload the
page and use the displayed pod name to confirm the target.

### Observe an exercise

1. In Grafana, open the provisioned **Practice Lab** dashboard and choose the
   `hello-staging` namespace. It contains request rate, p95 latency, 5xx rate,
   available app pods, active lab modes, pod/restart state, and Loki logs.
2. Use [the lab status endpoint](https://hello-staging.opsguy.io/lab/status)
   when you want the exact current pod-local state as JSON.
3. Use normal Kubernetes inspection commands when practising diagnosis:

   ```sh
   kubectl -n hello-staging get pods
   kubectl -n hello-staging get endpoints hello-api-staging-hello-api
   kubectl -n hello-staging get events --sort-by=.lastTimestamp
   kubectl -n hello-staging logs deploy/hello-api-staging-hello-api
   ```

### Current boundaries

Latency, errors, readiness, application metrics, Grafana panels, and the
staging k6 templates are deployed. CPU-burn and memory-pressure UI controls,
the UI trigger for k6, Vault/PostgreSQL integration, and container-level
CPU/memory Grafana panels are **not** built yet. The UI k6 trigger is the next
change; do not mistake the optional CLI fallback below for the intended primary
workflow.

## Optional CLI k6 fallback

Staging currently has three **suspended** k6 CronJobs. They never schedule a
test by themselves. Until the UI trigger lands, start a fresh Job manually:

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
