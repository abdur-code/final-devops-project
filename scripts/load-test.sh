#!/usr/bin/env bash
# Usage: ./scripts/load-test.sh [base-url] [concurrency] [seconds]
set -euo pipefail
URL="${1:-http://stockpilot.local}"
CONC="${2:-20}"
SECS="${3:-180}"
END=$(( $(date +%s) + SECS ))
echo "Hammering $URL/api/load with $CONC workers for ${SECS}s"
worker() { while [ "$(date +%s)" -lt "$END" ]; do curl -s -o /dev/null "$URL/api/load?ms=300" || true; done; }
for _ in $(seq "$CONC"); do worker & done
wait
echo "done. The HPA scales back down after its 120s stabilization window."
