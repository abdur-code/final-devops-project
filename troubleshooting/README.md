# Troubleshooting challenge

Everything in this folder is a broken version of the project. Each scenario is the kind of mistake that
happens for real: a typo in a manifest, a bad dependency, a wrong value in the GitOps repo. I broke each
one, tracked down the cause, fixed it and checked the fix. The write-ups, with the real command output
and a screenshot for each, are in [`docs/TROUBLESHOOTING-LOG.md`](../docs/TROUBLESHOOTING-LOG.md).

## Part A: Kubernetes faults

These are Kustomize overlays on top of the working `kubernetes/` manifests. They deploy to the
`stockpilot-raw` namespace, so the Helm/GitOps release keeps running while you break things.

```bash
make raw-deploy                       # healthy baseline
make break S=01-image-pull            # introduce a fault
./troubleshooting/diagnose.sh         # collect pods, events, describes, logs into troubleshooting/reports/
make raw-deploy                       # restore the baseline
```

| # | Overlay | Symptom |
|---|---------|---------|
| 01 | `01-image-pull` | New backend pods never start |
| 02 | `02-crashloop-config` | After a restart, new backend pods fail their init container over and over |
| 03 | `03-secret-key` | The database pod won't start, and stays stuck after the fix until you delete it |
| 04 | `04-service-selector` | UI loads, every API call fails |
| 05 | `05-readiness-probe` | Pods Running, rollout never finishes |
| 06 | `06-oomkilled` | Backend restarts every few seconds |
| 07 | `07-pvc-pending` | Database pod stuck in Pending (delete `sts/postgres` and `pvc/data-postgres-0` before applying) |
| 08 | `08-hpa-unknown` | Autoscaler targets show `<unknown>` |
| 09 | `09-ingress-port` | `/` works, `/api/...` returns 503 |
| 10 | `10-networkpolicy` | New API pods never become Ready, while the running ones look fine |

## Part B: CI/CD, DevSecOps and GitOps faults

```bash
./troubleshooting/pipeline/break.sh failing-test     # or: vulnerable-dep | leaked-secret | bad-gitops-tag
```

The script makes a branch called `break/<scenario>` with the bad commit on it. Push it and open a PR to
see what the pipeline does.

| # | Scenario | Symptom |
|---|----------|---------|
| 11 | `failing-test` | Red pipeline, nothing built or deployed |
| 12 | `vulnerable-dep` | Security gate fails although tests pass |
| 13 | `leaked-secret` | Secret-scanning job fails |
| 14 | `bad-gitops-tag` | Argo CD shows the dev app as Degraded |

To see drift correction, run `kubectl scale deploy/stockpilot-frontend -n stockpilot --replicas=5`. Argo CD's self-heal reverts it.
