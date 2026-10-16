#!/usr/bin/env bash
# Usage: ./troubleshooting/pipeline/break.sh failing-test|vulnerable-dep|leaked-secret|bad-gitops-tag
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
S="${1:?usage: $0 failing-test|vulnerable-dep|leaked-secret|bad-gitops-tag}"
git diff --quiet && git diff --cached --quiet || { echo "Commit or stash your changes first."; exit 1; }
git switch -c "break/$S"

case "$S" in
  failing-test)
    sed -i.bak 's/    item.sku = item.sku.upper()/    item.sku = item.sku/' application/backend/app/main.py
    rm -f application/backend/app/main.py.bak
    git add application/backend/app/main.py
    git commit -m "feat: keep SKU casing as entered" ;;
  vulnerable-dep)
    echo "requests==2.31.0" >> application/backend/requirements.txt
    git add application/backend/requirements.txt
    git commit -m "feat: add HTTP client for supplier API" ;;
  leaked-secret)
    TOKEN="ghp_$(head -c 600 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-36)"
    printf '# supplier API integration\nSUPPLIER_API_TOKEN = "%s"\n' "$TOKEN" > application/backend/app/supplier.py
    git add application/backend/app/supplier.py
    git commit -m "feat: supplier API client" ;;
  bad-gitops-tag)
    yq -i '.backend.image.tag = "0000000-does-not-exist"' gitops/environments/dev/values.yaml
    git add gitops/environments/dev/values.yaml
    git commit -m "chore(gitops): deploy hotfix to dev" ;;
  *) echo "unknown scenario $S"; exit 1 ;;
esac
echo "Broken on branch break/$S. Push it and watch the pipeline / Argo CD."
