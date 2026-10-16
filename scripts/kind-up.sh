#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
kind get clusters | grep -qx stockpilot || kind create cluster --config kind-config.yaml
kubectl cluster-info --context kind-stockpilot
echo
echo "Hostnames used by the Ingress (hosts file entry):"
echo "127.0.0.1 stockpilot.local raw.stockpilot.local"
