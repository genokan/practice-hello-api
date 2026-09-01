# Kubernetes Interview Triage

Do not try to memorize every Kubernetes object. Start with the same progression
for every deployment incident: desired state, Pod state, Events, logs, then
resource and traffic evidence.

```sh
kubectl get deployment,replicaset,pods -n hello-staging
kubectl get events -n hello-staging --sort-by=.lastTimestamp
kubectl describe pod <pod-name> -n hello-staging
kubectl logs <pod-name> -n hello-staging
kubectl logs <pod-name> -n hello-staging --previous
```

| Symptom | Evidence to find | First commands |
| --- | --- | --- |
| `Pending` | scheduler Event: insufficient CPU/memory, taint, affinity, or volume issue | `kubectl describe pod <pod-name> -n hello-staging` |
| `ImagePullBackOff` | `Failed to pull image` / `Back-off pulling image` Event; no container logs | `kubectl describe pod <pod-name> -n hello-staging` |
| `CrashLoopBackOff` | terminated reason and exit code, rising restarts, `Back-off restarting failed container` Event | `kubectl logs <pod-name> -n hello-staging --previous` |
| `OOMKilled` | last terminated reason `OOMKilled`, usually exit code 137, rising restarts | `kubectl describe pod <pod-name> -n hello-staging`; `kubectl top pods -n hello-staging` |
| `Running` but not Ready | failed readiness probe Event; missing Service endpoint | `kubectl describe pod <pod-name> -n hello-staging`; `kubectl get endpointslice -n hello-staging` |
| latency under load | CPU approaches its limit and throttling/latency rise; Pods may stay Ready | `kubectl top pods -n hello-staging`; Grafana CPU and p95 panels |

## CPU versus memory

CPU limits throttle rather than kill a container. Expect a Pod to remain
`Running`/`Ready` while `kubectl top pods` approaches the 200m container limit,
Grafana shows CPU throttling, and p95 latency rises under k6 load.

Memory limits are different: exceeding the 256Mi limit causes the kernel to
kill the container. Look for `OOMKilled`, exit code 137, a restart count, and
`kubectl logs --previous`. Use the staging `/lab` Memory control with a value
above the limit while a modest k6 profile is running.

## Argo CD first check

Before debugging the workload, establish whether the desired Git state reached
the cluster:

```sh
kubectl get application hello-api-staging -n argocd
kubectl describe application hello-api-staging -n argocd
kubectl rollout status deployment/hello-api-staging-hello-api -n hello-staging
```

`Synced` answers whether Argo applied the intended manifest. `Healthy` answers
whether the resulting Kubernetes resources are healthy. They are related but
not interchangeable.
