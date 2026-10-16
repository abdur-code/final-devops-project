#!/usr/bin/env bash
# Usage: ./troubleshooting/diagnose.sh [namespace]
set -uo pipefail
NS="${1:-stockpilot-raw}"
OUT="troubleshooting/reports/$(date +%Y%m%d-%H%M%S)-$NS.txt"
mkdir -p "$(dirname "$OUT")"
run() { printf '\n===== $ %s =====\n' "$*"; "$@" 2>&1; }
{
  run kubectl get pods,svc,endpoints,deploy,sts,pvc,hpa,ingress,networkpolicy -n "$NS" -o wide
  run kubectl get events -n "$NS" --sort-by=.lastTimestamp
  for p in $(kubectl get pods -n "$NS" -o name); do
    run kubectl describe -n "$NS" "$p"
    run kubectl logs -n "$NS" "$p" --all-containers --tail=50
    run kubectl logs -n "$NS" "$p" --all-containers --previous --tail=30
  done
  run kubectl top pods -n "$NS"
} > "$OUT"
echo "report written to $OUT"
