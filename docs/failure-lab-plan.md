# Failure Lab Plan

## Purpose

Turn `hello-api` into a controlled, observable staging-only failure lab for
practising the deployment and incident scenarios expected of an SRE. The lab
must make a failure easy to start, explainable from Grafana and Kubernetes, and
safe to reset without changing cluster infrastructure.

This is an application exercise, not a new shared platform. The application
source, Helm chart, fault controls, metrics, and k6 scripts belong in this
repository. `practice-lab` continues to own the staging and production values
that Argo CD deploys; `home-docker` continues to provision Grafana.

## Current implementation status

Implemented and deployed:

- staging runs two pods and production runs three;
- staging has the `/lab` console with bounded latency, error, readiness, CPU,
  and memory modes, reset, expiry, and pod-local state; production disables it;
- `/metrics` exposes request counters, duration histograms, availability, and
  active-lab-mode metrics; Prometheus and the existing `Practice Lab` Grafana
  dashboard collect and display them;
- staging renders suspended `hello-api-load-{smoke,standard,spike,stress,sustained}`
  CronJobs; the UI starts a Job from one selected template through a narrowly
  scoped namespace Role;
- the chart supports a 200m CPU limit, a soft hostname spread preference, and
  an optional PDB. Staging currently uses `minAvailable: 1`. Production has
  its CPU limit but needs its normal release-driven chart promotion before the
  new PDB template is available there.

Still planned: deliberate process exit, a Vault-delivered PostgreSQL credential
and real query, and the follow-on HPA/dependency/network exercises.

## Desired end state

Staging has two `hello-api` pods behind the existing service and ingress;
production has three. A
small HTML control page at `https://hello-staging.opsguy.io/lab` can activate a
bounded fault on the individual pod that receives the request. Versioned k6
profiles produce realistic concurrent requests. Grafana shows request rate,
errors, p95/p99 latency, pod resource pressure, readiness, restarts, and the
active lab mode alongside matching Loki logs.

Production never enables the control page, in-process fault code, or k6
resources.

## Design principles

- **Staging only.** `lab.enabled` is false by default and in production. Every
  mutating lab endpoint returns `404` when it is disabled.
- **No cluster credentials in the application.** The UI controls only its own
  process. It never creates Jobs, alters Deployments, or calls the Kubernetes
  API.
- **Bounded and reversible.** Every fault has a duration, a maximum setting,
  an explicit reset action, and a pod restart as the guaranteed last-resort
  reset.
- **Pod-local on purpose.** Fault state lives in the target pod's memory. This
  lets a replicated service demonstrate partial failure and load balancing;
  the page displays its pod hostname so the target is unambiguous.
- **No new monitoring platform.** Extend the Prometheus, Loki, and Grafana
  paths already in use.
- **Normal Kubernetes operation.** A suspended CronJob provides the k6 Job
  template and test runs start with `kubectl create job`; no bespoke wrapper
  is introduced.

## Repository layout

```text
practice-hello-api/
  docs/failure-lab-plan.md
  lib/hello_elixir/lab/          # fault state, workers, metric accumulator
  lib/hello_elixir_web/          # /lab HTML and JSON control endpoints
  chart/files/k6/
    smoke.js
    spike.js
    sustained.js
  chart/templates/
    lab-load-configmap.yaml
    lab-load-cronjobs.yaml

practice-lab/
  k8s/apps/hello-api/values/staging.yaml
  k8s/apps/hello-api/values/prod.yaml

home-docker/
  config/monitoring/dashboards/practice-lab.json
```

## Deployment baseline

Set staging to two replicas and production to three. This keeps staging cheaper
while production exercises the more typical three-pod baseline. Neither is
node-level HA because all pods remain on the single k3s VM.

```yaml
# staging
replicaCount: 2

# production
replicaCount: 3

# both environments
resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

Add environment-appropriate `PodDisruptionBudget`s: staging keeps one of its
two pods available and production keeps two of its three. Add a *preferred*
topology spread rule. The latter must stay soft: a required node spread rule
would make pods unschedulable on a one-node cluster. A later autoscaling
exercise can add an HPA with `minReplicas: 3` and `maxReplicas: 6`; it is
deliberately not part of the first implementation.

## Fault console

The existing app is a JSON Phoenix service. Add a separate HTML pipeline and a
small server-rendered page rather than adding LiveView or a frontend build.
The page exposes the active mode, target pod hostname, bounded inputs,
countdown, reset button, and links to the Grafana dashboard and filtered logs.

The page is available only with `LAB_ENABLED=true`, supplied by the staging
Helm values. It uses the existing TLS/Caddy route at the staging hostname. If
that hostname becomes reachable outside the trusted home network, place an
authentication rule in Caddy before enabling the console; credentials must be
Vault-backed rather than committed.

Implement a supervised `HelloElixir.Lab` state process and worker supervisor.
The lab state exposes a read-only status endpoint for the page and `/metrics`.
It records the current mode, expiry, worker count, and fault-specific settings.
All worker creation and input validation happens server-side.

### Initial scenarios

| Scenario | UI controls | Expected observation | Reset |
| --- | --- | --- | --- |
| CPU burn | workers, duration | CPU approaches the limit; throttling and latency rise under k6 | expiry/reset |
| Memory pressure | retained MiB, duration | memory reaches limit; an intentionally oversized run produces `OOMKilled` and a pod restart | expiry/reset or pod restart |
| Readiness failure | duration | one pod leaves service endpoints while remaining live | expiry/reset |
| Latency injection | delay, percentage, duration | p95/p99 and k6 latency climb without pod failure | expiry/reset |
| Error injection | error percentage, duration | 5xx rate and error logs rise | expiry/reset |
| Deliberate process exit | confirmation | one pod enters a restart/CrashLoop scenario | Kubernetes restart |

CPU work uses bounded BEAM tasks doing deterministic hash work. Memory pressure
holds binaries under supervised worker processes. Neither mode may accept an
unbounded concurrency, allocation, or duration. The process-exit operation
needs an explicit confirmation step and is implemented only after the first
five scenarios are working.

An optional second wave can simulate an unreachable database/dependency once a
real Vault-delivered database credential is present. It is not a prerequisite
for the first lab because the current database check is intentionally optional.

## Metrics and logs

Replace the current informational-only `/metrics` output with a small
Prometheus-compatible accumulator. It must retain the existing `up` and `info`
series and add:

```text
hello_api_http_requests_total{route,status}
hello_api_http_request_duration_seconds_bucket{route,le}
hello_api_http_request_duration_seconds_sum{route}
hello_api_http_request_duration_seconds_count{route}
hello_api_lab_mode_active{mode}
hello_api_lab_workers
hello_api_lab_readiness_forced
```

The duration histogram uses fixed, cumulative buckets suitable for
`histogram_quantile()`; p95 and p99 are calculated by Prometheus/Grafana, not
inside the app. Log every mode transition and sampled injected error with the
pod hostname and a correlation identifier so the Loki panel explains a graph
spike.

Extend the existing provisioned `Practice Lab` dashboard in `home-docker`;
do not create a duplicate dashboard. Add a `hello-api` row containing:

1. request rate and 5xx percentage;
2. p50, p95, and p99 request latency;
3. active lab mode and forced-readiness state;
4. CPU use, CPU throttling, and CPU request/limit;
5. memory use, memory limit, restarts, and `OOMKilled` evidence;
6. desired/available replica count and ready endpoints;
7. a Loki panel scoped to the `hello-api` staging pods.

Use a short scrape interval for `hello-api` if the existing 30-second global
interval makes short exercises invisible. Ten seconds is appropriate for this
lab and should be configured only for this target.

## k6 load generation

k6 profiles are source-controlled alongside the app because their target and
assertions are app-specific. The chart renders their scripts into a ConfigMap
and creates suspended staging-only CronJobs. Argo deploys these templates but
never starts a load run.

Profiles:

- `smoke`: low, short traffic to verify a deployment;
- `standard`: a 30-minute moderate baseline that can run with an additional
  spike or stress Job;
- `spike`: a quick rise in virtual users for CPU/throttling and error testing;
- `stress`: deliberately high concurrency for saturation and throttling;
- `sustained`: several minutes of steady traffic for latency and memory trends.

Run a profile from the staging `/lab` UI. The app ServiceAccount can read only
the chart-declared CronJob templates and create/list Jobs in its own namespace;
it cannot modify workloads, secrets, or delete resources. Jobs self-clean by
TTL. `kubectl` remains useful for inspecting outcomes, not as the start path.

The first profiles target the in-cluster service DNS so they isolate application
behaviour. A later ingress profile can target `https://hello-staging.opsguy.io`
to include Caddy, Traefik, TLS, and DNS in the exercise.

## Implementation phases

### 1. Baseline and observability

1. Set staging to two replicas and production to three; add CPU limits, a PDB,
   and a soft topology spread rule to the application chart. Keep all fault and
   load controls disabled in production.
2. Add request-count and request-duration instrumentation and test the
   Prometheus exposition format.
3. Extend the existing Grafana dashboard and confirm each new series appears
   from all three pods.
4. Document a baseline screenshot/query set before any failure is activated.

**Acceptance:** two ready staging pods and three ready production pods serve
their intended environments; Grafana shows request rate, p95/p99, CPU, memory,
restarts, readiness, and logs for each pod.

### 2. Fault console and safe modes

1. Add the staging-gated `/lab` page and read-only status endpoint.
2. Add CPU, latency, error-rate, readiness, and memory scenarios with strict
   validation, expiry, reset, metrics, and logs.
3. Test each mode through one pod while the service stays available through the
   other replicas.
4. Add the confirmed deliberate-process-exit scenario last.

**Acceptance:** an expired/reset scenario leaves no worker or retained-memory
state; a pod restart also clears state; production responds `404` for all lab
routes.

### 3. k6 profiles and runbooks

1. Add ConfigMap/CronJob templates and smoke, spike, and sustained scripts.
2. Run each profile manually as a Job; verify its output, dashboard signals,
   and Loki entries.
3. Add one concise runbook per scenario: trigger, expected symptoms, evidence
   commands, likely diagnosis, and remediation.

**Acceptance:** a fresh clone plus the documented `kubectl create job` command
reproduces every initial scenario without an app-held Kubernetes credential or
manual dashboard edits.

### 4. Follow-on exercises

Add HPA, an ingress-targeted k6 profile, dependency/database failure, network
policy/DNS exercises, a bad rolling rollout, and alert rules only after the
baseline lab is stable.

## Validation commands

These are normal operational commands used during the exercise:

```sh
kubectl -n hello-api-staging get pods -o wide
kubectl -n hello-api-staging get endpoints hello-api
kubectl -n hello-api-staging top pods
kubectl -n hello-api-staging get events --sort-by=.lastTimestamp
kubectl -n hello-api-staging describe pod <pod-name>
kubectl -n hello-api-staging logs <pod-name> --previous
```

## Deliberate exclusions

- No k6 operator, cluster-scoped role, workload mutation, secret access, or
  job-deletion access from the app.
- No production failure controls or load CronJobs.
- No hard pod anti-affinity or required topology spread on the one-node VM.
- No automatic chaos schedule; every fault and load run is manually initiated
  and visible.
