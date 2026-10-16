# Monitoring and logging

```
backend /metrics ──▶ ServiceMonitor ──▶ Prometheus ──▶ Grafana dashboards
                                          │
                                          └─▶ PrometheusRule alerts ──▶ Alertmanager
pod stdout (JSON logs) ──▶ Alloy ──▶ Loki ──▶ Grafana Explore / logs panel
```

| File | Purpose |
|------|---------|
| `kube-prometheus-stack-values.yaml` | Prometheus Operator, Prometheus, Alertmanager, Grafana, kube-state-metrics, node-exporter |
| `loki-values.yaml` | Loki in single-binary mode (log storage) |
| `alloy-values.yaml` | Grafana Alloy: ships every pod's logs to Loki |
| `grafana/dashboards/stockpilot.json` | App dashboard (a copy lives in the Helm chart; CI checks they match) |
| `local/` | Prometheus + Grafana config for `docker compose --profile monitoring` |
| `install.sh` | Installs the stack without Argo CD |

With GitOps, Argo CD deploys the same values files (`gitops/apps/monitoring.yaml`).

## What the app exposes
- `http_requests_total` and `http_request_duration_seconds` (per endpoint, method and status) from the FastAPI instrumentator
- `stockpilot_inventory_operations_total{operation}`, a business metric
- Structured JSON logs with `method`, `path`, `status` and `duration_ms`, so Loki can filter on them: `{container="backend"} | json | status >= 400`

## Alerts
The rules are in `helm/stockpilot/templates/prometheusrule.yaml`. They fire when the backend is down, the 5xx rate
is above 5%, p95 latency is above 500ms, a pod keeps restarting, or the HPA is at its maximum.

## Access
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80        # Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090   # Prometheus → Status → Targets
kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d
```
