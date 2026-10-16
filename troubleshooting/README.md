# Troubleshooting challenge

This folder holds fourteen deliberately broken versions of the project. Each one is a realistic mistake
in a manifest, a dependency file or a GitOps value. Each fault is worked through the same six steps:
identify, investigate, find the root cause, fix, verify and document. The write-ups are in
[`docs/TROUBLESHOOTING-LOG.md`](../docs/TROUBLESHOOTING-LOG.md).

## Part A: Kubernetes faults

These are Kustomize overlays on top of the healthy `kubernetes/` manifests. They deploy to the
`stockpilot-raw` namespace, so they never touch the Helm/GitOps release.

```bash
make raw-deploy                       # healthy baseline
make break S=01-image-pull            # introduce a fault
./troubleshooting/diagnose.sh         # collect pods, events, describes, logs into troubleshooting/reports/
make raw-deploy                       # restore the baseline
```

| # | Overlay | Symptom |
|---|---------|---------|
| 01 | `01-image-pull` | New backend pods never start |
| 02 | `02-crashloop-config` | Backend pods restart over and over |
| 03 | `03-secret-key` | The database pod won't start |
| 04 | `04-service-selector` | UI loads, every API call fails |
| 05 | `05-readiness-probe` | Pods Running, rollout never finishes |
| 06 | `06-oomkilled` | Backend restarts every few seconds |
| 07 | `07-pvc-pending` | Database pod stuck in Pending |
| 08 | `08-hpa-unknown` | Autoscaler targets show `<unknown>` |
| 09 | `09-ingress-port` | `/` works, `/api/...` returns 503 |
| 10 | `10-networkpolicy` | API pods never become Ready |

## Part B: CI/CD, DevSecOps and GitOps faults

```bash
./troubleshooting/pipeline/break.sh failing-test     # or: vulnerable-dep | leaked-secret | bad-gitops-tag
```

The script creates a branch named `break/<scenario>` that contains the faulty commit.

| # | Scenario | Symptom |
|---|----------|---------|
| 11 | `failing-test` | Red pipeline, nothing built or deployed |
| 12 | `vulnerable-dep` | Security gate fails although tests pass |
| 13 | `leaked-secret` | Secret-scanning job fails |
| 14 | `bad-gitops-tag` | Argo CD shows the dev app as Degraded |

For a drift experiment, run `kubectl scale deploy/stockpilot-frontend -n stockpilot --replicas=5`. Argo CD self-heal reverts it.
