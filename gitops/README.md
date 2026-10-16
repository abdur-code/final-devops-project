# GitOps with Argo CD

Git is the single source of truth. CI never runs `kubectl` against the cluster; a deploy goes through Git instead:

```
merge to main ─▶ CI builds, scans, pushes ghcr.io/<you>/stockpilot-*:<sha>
              └▶ CI commits "deploy <sha> to dev" to gitops/environments/dev/values.yaml
                         │
Argo CD (in the cluster) polls Git ─▶ sees the new commit ─▶ helm-renders the chart ─▶ syncs
```

| Path | What it is |
|------|-----------|
| `argocd/argocd-values.yaml` | Helm values for installing Argo CD |
| `argocd/project.yaml` | AppProject: which repos and namespaces Argo CD may use |
| `argocd/root-app.yaml` | App-of-apps: the only manifest applied by hand |
| `apps/stockpilot-dev.yaml` | Dev app: chart from `helm/stockpilot` with values from `environments/dev`, auto-sync and self-heal |
| `apps/monitoring.yaml` | kube-prometheus-stack, Loki and Alloy, also managed from Git |
| `argocd/optional/stockpilot-prod.yaml` | Prod app, synced manually |
| `environments/dev/values.yaml` | Image tags written by CI |
| `environments/prod/values.yaml` | Promoted by pull request |

To install, run `./scripts/bootstrap-cluster.sh`. It installs Argo CD and applies the project and the root app.

## Day-to-day operations
- Deploy: merge to main. Nothing else is needed.
- Roll back: `git revert <gitops commit> && git push`.
- Promote to prod: open a PR that copies the tag from `environments/dev` to `environments/prod`, merge it, then Sync.
- Drift: manual `kubectl` edits are reverted automatically (`selfHeal: true`).

Argo CD reads the repository anonymously, which is why the repository is public; a private repository
would need a read-only deploy key registered in Argo CD.
