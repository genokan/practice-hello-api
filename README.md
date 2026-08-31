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
| CPU | Starts bounded hash workers in that pod | CPU usage, throttling, p95 latency, and queueing under load |
| Memory | Retains the selected MiB in that pod | Working set, OOMKilled/restarts when the 256Mi limit is exceeded |
| Reset | Immediately removes the active scenario from that pod | The active-mode dashboard panel returns to idle |

Every scenario has a 1–300 second expiry. The controls are deliberately
pod-local: with two staging replicas, a partial failure and load balancing are
part of the exercise. If the browser is routed to the other pod, reload the
page and use the displayed pod name to confirm the target.

### Observe an exercise

1. In Grafana, open the provisioned **hello-api** dashboard and choose the
   `hello-staging` namespace. It contains request rate by status, 5xx percentage
   and status breakdown, latency percentiles, CPU/throttling, memory, lab mode,
   and Loki logs. **Practice Lab** remains the generic cluster view.
2. Use [the lab status endpoint](https://hello-staging.opsguy.io/lab/status)
   when you want the exact current pod-local state as JSON.
3. Use normal Kubernetes inspection commands when practising diagnosis:

   ```sh
   kubectl -n hello-staging get pods
   kubectl -n hello-staging get endpoints hello-api-staging-hello-api
   kubectl -n hello-staging get events --sort-by=.lastTimestamp
   kubectl -n hello-staging logs deploy/hello-api-staging-hello-api
   ```

### Run load from the UI

The same page starts a k6 Job from one of five chart-declared staging profiles.
The application has a dedicated namespace-scoped service account that may only
read those CronJob templates and create/list Jobs; it cannot modify workloads,
Secrets, or delete anything. The page lists browser-started Jobs and they
self-clean an hour after completion. While a Job is active, the page refreshes
every five seconds and shows its Running, Passed, or Failed state.

- `smoke`: light deployment verification.
- `standard`: 10 virtual users for 30 minutes; use this as the baseline while
  layering a spike or stress run over it.
- `spike`: ramps to 200 virtual users over 90 seconds.
- `stress`: ramps to 300 virtual users for a deliberately demanding two-minute run.
- `sustained`: 25 virtual users for five minutes.

The profiles target the in-cluster Service (`/work`), isolating application and
Service behavior from Caddy, Traefik, TLS, and DNS. They exist only in staging.
Jobs are independent, so the standard profile can run alongside another profile.
Normal `kubectl` inspection is still useful during an exercise, but it is not
required to launch one.

### Current boundaries

Latency, 503 errors, readiness, CPU burn, memory pressure, application metrics,
the service-specific Grafana dashboard, and browser-started staging k6 profiles
are deployed. Fault state remains intentionally pod-local. Vault/PostgreSQL and
PgBouncer integration are deferred so the first exercises isolate application
and Kubernetes behavior from dependency failures.
