#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 02-cluster-addons.sh — GPU device plugin, internal ingress, KEDA, Key Vault.
# ---------------------------------------------------------------------------
set -euo pipefail
: "${RG:?source scripts/00-prereqs.sh first}"

echo "==> NVIDIA device plugin (exposes nvidia.com/gpu to the scheduler)"
# Tolerates the GPU taint so it can run on the GPU nodes.
kubectl apply -f k8s/nvidia-device-plugin.yaml
echo "    waiting for a node to advertise a GPU..."
kubectl -n kube-system rollout status ds/nvidia-device-plugin-daemonset --timeout=10m || true

echo "==> ingress-nginx with an INTERNAL Azure load balancer"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo update >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"=true \
  --set controller.service.externalTrafficPolicy=Local

echo "==> KEDA (event-driven autoscaling for the vLLM deployment)"
helm repo add kedacore https://kedacore.github.io/charts >/dev/null
helm repo update >/dev/null
helm upgrade --install keda kedacore/keda --namespace keda --create-namespace

echo "==> kube-prometheus-stack (Prometheus + Grafana) for metrics"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword='change-me-please'

echo "==> Grant AKS Key Vault access (store the HF token + vLLM API key there)"
az keyvault create -g "$RG" -n "$KEYVAULT" -l "$LOCATION" \
  --enable-rbac-authorization true -o none

# The secrets provider addon created a user-assigned identity; grab its clientId.
IDENTITY_CLIENT_ID=$(az aks show -g "$RG" -n "$AKS" \
  --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv)
IDENTITY_OBJECT_ID=$(az aks show -g "$RG" -n "$AKS" \
  --query addonProfiles.azureKeyvaultSecretsProvider.identity.objectId -o tsv)
KV_ID=$(az keyvault show -g "$RG" -n "$KEYVAULT" --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

az role assignment create --assignee "$IDENTITY_OBJECT_ID" \
  --role "Key Vault Secrets User" --scope "$KV_ID" -o none

echo "==> Store secrets (replace with your real values)"
az keyvault secret set --vault-name "$KEYVAULT" --name hf-token    --value "hf_xxxxxxxxxxxxxxxx" -o none
az keyvault secret set --vault-name "$KEYVAULT" --name vllm-api-key --value "$(openssl rand -hex 24)" -o none

cat <<EOF

------------------------------------------------------------------
Fill these into k8s/secretprovider.yaml:
  keyvaultName : $KEYVAULT
  tenantId     : $TENANT_ID
  clientID     : $IDENTITY_CLIENT_ID
------------------------------------------------------------------
EOF
