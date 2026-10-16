#!/usr/bin/env bash
# Usage: ./security/scan-local.sh [--images]
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n\033[1;33m▶ %s\033[0m\n' "$*"; }

step "Secret scanning (gitleaks, full git history)"
gitleaks git . --config security/gitleaks.toml --redact

step "SAST: bandit"
pip install --quiet bandit==1.9.4 && bandit -c security/bandit.yaml -r application/backend/app -ll

step "SAST: semgrep"
if command -v semgrep >/dev/null; then
  semgrep scan --metrics=off --error --severity ERROR --config p/python --config p/javascript \
    --config p/dockerfile --config security/semgrep-rules.yml application docker
else
  echo "semgrep not installed (pip install semgrep), skipping"
fi

step "SCA: pip-audit + npm audit"
pip install --quiet pip-audit==2.10.1 && pip-audit -r application/backend/requirements.txt
(cd application/frontend && npm audit --audit-level=high)

step "IaC misconfiguration (trivy config)"
trivy config --severity HIGH,CRITICAL --ignorefile security/.trivyignore .

if [[ "${1:-}" == "--images" ]]; then
  for c in backend frontend; do
    step "Container image scan: $c"
    docker build -q -f docker/$c.Dockerfile -t stockpilot-$c:scan application/$c
    trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --ignorefile security/.trivyignore stockpilot-$c:scan
  done
fi
printf '\n\033[1;32mAll security gates passed\033[0m\n'
