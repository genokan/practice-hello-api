# hello-api

![Version: 0.1.3](https://img.shields.io/badge/Version-0.1.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.27.6](https://img.shields.io/badge/AppVersion-1.27.6-informational?style=flat-square)

A tiny, intentionally replaceable workload for the practice lab.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| environment | string | `"development"` |  |
| image.digest | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"nginxinc/nginx-unprivileged"` |  |
| image.tag | string | `"1.27.5-alpine"` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `"traefik"` |  |
| ingress.enabled | bool | `false` |  |
| ingress.host | string | `""` |  |
| lab.enabled | bool | `false` |  |
| lab.maxDurationSeconds | int | `300` |  |
| lab.maxLatencyMilliseconds | int | `5000` |  |
| podAnnotations | object | `{}` |  |
| replicaCount | int | `1` |  |
| resources.limits.memory | string | `"64Mi"` |  |
| resources.requests.cpu | string | `"25m"` |  |
| resources.requests.memory | string | `"32Mi"` |  |
| secretEnv | list | `[]` |  |
| service.port | int | `80` |  |
| service.targetPort | int | `8080` |  |
| service.type | string | `"ClusterIP"` |  |

