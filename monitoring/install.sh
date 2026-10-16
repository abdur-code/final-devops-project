#!/usr/bin/env bash
# Installs the monitoring stack without Argo CD.
set -euo pipefail
cd "$(dirname "$0")"

KPS_VERSION=92.8.0
LOKI_VERSION=7.2.0
ALLOY_VERSION=1.13.0

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl get secret grafana-admin -n monitoring >/dev/null 2>&1; then
  PASS="$(openssl rand -hex 12)"
  kubectl create secret generic grafana-admin -n monitoring \
    --from-literal=admin-user=admin --from-literal=admin-password="$PASS"
  echo "Grafana admin password: $PASS   (also: kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d)"
fi

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version "$KPS_VERSION" -n monitoring -f kube-prometheus-stack-values.yaml --wait --timeout 10m
helm upgrade --install loki grafana/loki --version "$LOKI_VERSION" -n monitoring -f loki-values.yaml --wait
helm upgrade --install alloy grafana/alloy --version "$ALLOY_VERSION" -n monitoring -f alloy-values.yaml --wait

echo "Monitoring stack ready. Pods:"
kubectl get pods -n monitoring
