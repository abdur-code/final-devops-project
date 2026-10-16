#!/usr/bin/env bash
# Usage: ./scripts/bootstrap-cluster.sh [--kind] [--no-argocd]
set -euo pipefail
cd "$(dirname "$0")/.."

KIND=false; ARGOCD=true
for a in "$@"; do
  case "$a" in
    --kind) KIND=true ;;
    --no-argocd) ARGOCD=false ;;
  esac
done
INGRESS="${INGRESS:-nginx}"

INGRESS_NGINX_VERSION=4.15.0
TRAEFIK_VERSION=41.7.1
METRICS_SERVER_VERSION=3.14.0
ARGOCD_VERSION=10.10.3

if grep -rq "abdur-code" gitops/apps gitops/argocd; then
  echo "Error: placeholders still present. Run: ./scripts/set-github-user.sh <your-github-username>"; exit 1
fi

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo add traefik https://traefik.github.io/charts >/dev/null
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server >/dev/null
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update >/dev/null

echo "▶ Ingress controller ($INGRESS)"
if [[ "$INGRESS" == "traefik" ]]; then
  EXTRA=(); $KIND && EXTRA=(--set ports.web.hostPort=80 --set ports.websecure.hostPort=443 --set service.type=NodePort)
  helm upgrade --install traefik traefik/traefik --version "$TRAEFIK_VERSION" -n ingress --create-namespace \
    --set ingressClass.name=traefik ${EXTRA[@]+"${EXTRA[@]}"} --wait
  echo "   Ingress class in use: traefik (ingress.className=traefik)"
else
  EXTRA=(); $KIND && EXTRA=(--set controller.hostPort.enabled=true --set controller.service.type=NodePort)
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --version "$INGRESS_NGINX_VERSION" \
    -n ingress-nginx --create-namespace ${EXTRA[@]+"${EXTRA[@]}"} --wait
fi

echo "▶ metrics-server (HPA needs CPU/memory metrics)"
EXTRA=(); $KIND && EXTRA=(--set "args={--kubelet-insecure-tls}")
helm upgrade --install metrics-server metrics-server/metrics-server --version "$METRICS_SERVER_VERSION" \
  -n kube-system ${EXTRA[@]+"${EXTRA[@]}"} --wait

if ! $KIND; then
  echo "▶ gp3 StorageClass (EKS)"
  kubectl apply -f kubernetes/storageclass-gp3.yaml
  kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class=false --overwrite 2>/dev/null || true
fi

echo "▶ Database secret (random password, lives only in the cluster)"
./scripts/create-db-secret.sh stockpilot

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl get secret grafana-admin -n monitoring >/dev/null 2>&1; then
  kubectl create secret generic grafana-admin -n monitoring \
    --from-literal=admin-user=admin --from-literal=admin-password="$(openssl rand -hex 12)"
fi

if $ARGOCD; then
  echo "▶ Argo CD"
  helm upgrade --install argocd argo/argo-cd --version "$ARGOCD_VERSION" -n argocd --create-namespace \
    -f gitops/argocd/argocd-values.yaml --wait
  kubectl apply -f gitops/argocd/project.yaml -f gitops/argocd/root-app.yaml
  echo
  echo "Argo CD UI:   kubectl port-forward -n argocd svc/argocd-server 8081:80  (http://localhost:8081)"
  echo "   user: admin   password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
else
  echo "Skipping Argo CD. Install monitoring with ./monitoring/install.sh and the app with helm (see README)."
fi
echo
echo "Grafana password: kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d"
echo "Bootstrap complete."
