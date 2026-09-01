# hello-api

![Version: 0.1.9](https://img.shields.io/badge/Version-0.1.9-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.27.6](https://img.shields.io/badge/AppVersion-1.27.6-informational?style=flat-square)

A tiny, intentionally replaceable workload for the practice lab.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| environment | string | `"development"` |  |
| failureExercises.crashLoop.activeDeadlineSeconds | int | `600` |  |
| failureExercises.crashLoop.backoffLimit | int | `100` |  |
| failureExercises.crashLoop.image | string | `"busybox:1.36"` |  |
| failureExercises.enabled | bool | `false` |  |
| failureExercises.imagePull.activeDeadlineSeconds | int | `600` |  |
| failureExercises.imagePull.image | string | `"registry.invalid/practice-lab/image-pull-drill:never"` |  |
| image.digest | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"nginxinc/nginx-unprivileged"` |  |
| image.tag | string | `"1.27.5-alpine"` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `"traefik"` |  |
| ingress.enabled | bool | `false` |  |
| ingress.host | string | `""` |  |
| lab.enabled | bool | `false` |  |
| lab.maxCpuWorkers | int | `8` |  |
| lab.maxDurationSeconds | int | `300` |  |
| lab.maxLatencyMilliseconds | int | `5000` |  |
| lab.maxMemoryMiB | int | `512` |  |
| load.enabled | bool | `false` |  |
| load.image.pullPolicy | string | `"IfNotPresent"` |  |
| load.image.repository | string | `"grafana/k6"` |  |
| load.image.tag | string | `"1.7.1"` |  |
| load.namePrefix | string | `"hello-api-load"` |  |
| load.profiles[0].name | string | `"smoke"` |  |
| load.profiles[0].script | string | `"smoke.js"` |  |
| load.profiles[1].name | string | `"standard"` |  |
| load.profiles[1].script | string | `"standard.js"` |  |
| load.profiles[2].name | string | `"spike"` |  |
| load.profiles[2].script | string | `"spike.js"` |  |
| load.profiles[3].name | string | `"stress"` |  |
| load.profiles[3].script | string | `"stress.js"` |  |
| load.profiles[4].name | string | `"sustained"` |  |
| load.profiles[4].script | string | `"sustained.js"` |  |
| load.profiles[5].name | string | `"soak"` |  |
| load.profiles[5].script | string | `"soak.js"` |  |
| load.resources.limits.cpu | string | `"500m"` |  |
| load.resources.limits.memory | string | `"256Mi"` |  |
| load.resources.requests.cpu | string | `"50m"` |  |
| load.resources.requests.memory | string | `"64Mi"` |  |
| load.targetUrl | string | `"http://hello-api-staging-hello-api"` |  |
| load.ui.enabled | bool | `false` |  |
| podAnnotations | object | `{}` |  |
| podDisruptionBudget.enabled | bool | `false` |  |
| podDisruptionBudget.minAvailable | int | `1` |  |
| replicaCount | int | `1` |  |
| resources.limits.cpu | string | `"200m"` |  |
| resources.limits.memory | string | `"64Mi"` |  |
| resources.requests.cpu | string | `"25m"` |  |
| resources.requests.memory | string | `"32Mi"` |  |
| secretEnv | list | `[]` |  |
| service.port | int | `80` |  |
| service.targetPort | int | `8080` |  |
| service.type | string | `"ClusterIP"` |  |
| topologySpread.enabled | bool | `true` |  |
| topologySpread.maxSkew | int | `1` |  |
| topologySpread.topologyKey | string | `"kubernetes.io/hostname"` |  |

