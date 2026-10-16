#!/usr/bin/env bash
# Usage: ./scripts/create-db-secret.sh [namespace]
set -euo pipefail
NS="${1:-stockpilot}"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
if kubectl get secret stockpilot-db -n "$NS" >/dev/null 2>&1; then
  echo "secret stockpilot-db already exists in $NS (leaving it alone)"
else
  kubectl create secret generic stockpilot-db -n "$NS" \
    --from-literal=DB_USER=stockpilot \
    --from-literal=DB_PASSWORD="$(openssl rand -hex 16)"
  echo "created secret stockpilot-db in $NS"
fi
