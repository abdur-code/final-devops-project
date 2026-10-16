# DevSecOps

Security checks run automatically on every pull request. Each check is a gate: if it fails, the pipeline
stops and no image is built, pushed or deployed.

| Layer | Tool | Where | Gate (fails the build when…) |
|-------|------|-------|------------------------------|
| SAST | Semgrep (`p/python`, `p/javascript`, `p/dockerfile` + [`semgrep-rules.yml`](semgrep-rules.yml)) | `sast` job | any ERROR-severity finding |
| SAST | Bandit ([`bandit.yaml`](bandit.yaml)) + ruff `S` rules | `sast`, `backend-test` | medium+ severity issue |
| SCA | pip-audit, npm audit | `sca` job | any known CVE (Python) / high+ (npm) |
| SCA | Dependabot ([`../.github/dependabot.yml`](../.github/dependabot.yml)) | weekly PRs | n/a (keeps deps current) |
| Secret scanning | Gitleaks ([`gitleaks.toml`](gitleaks.toml)), full git history | `secret-scan` job + pre-commit | any secret found |
| IaC scanning | Trivy config (Terraform, K8s, Helm, Dockerfiles) | `iac-scan`, `terraform.yml` | CRITICAL misconfiguration |
| Container scanning | Trivy image | `build-images` job | HIGH/CRITICAL CVE with a fix available |
| Continuous scanning | Trivy on published images | `security-nightly.yml` | new HIGH/CRITICAL CVE |
| SBOM | Trivy CycloneDX | `build-images` artifact | n/a |

## Hardening built into the project
- Images use multi-stage builds and non-root users, upgrade OS packages at build time and pin their base tags.
- Kubernetes workloads set `runAsNonRoot` and `readOnlyRootFilesystem`, drop all Linux capabilities and use seccomp
  `RuntimeDefault`. The raw namespace enforces the Pod Security Admission `restricted` level, and a NetworkPolicy
  allows only the backend to reach PostgreSQL.
- Secrets are never stored in Git. `scripts/create-db-secret.sh` generates the database secret in the cluster, and CI
  passes a random value with `--set`.
- CI jobs each declare least-privilege `permissions:`. Third-party actions are pinned to commit SHAs because tags can
  be moved, as happened to `trivy-action` in March 2026. AWS access uses OIDC, so no keys are stored.

## Accepted risks
Accepted risks are listed in [`.trivyignore`](.trivyignore) with a justification for each. Every ignore entry
needs a reason and a review date.

## Run the gates locally
```bash
./security/scan-local.sh            # code, deps, secrets, IaC
./security/scan-local.sh --images   # + build and scan both images
```

## Possible improvements
Images could be signed with cosign (keyless, via GitHub OIDC) and the signatures enforced with Kyverno.
Secrets could move to External Secrets Operator backed by AWS Secrets Manager.
