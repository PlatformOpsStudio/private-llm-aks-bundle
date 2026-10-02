#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 01-create-aks.sh — resource group, VNet, AKS, and a tainted GPU node pool.
# ---------------------------------------------------------------------------
set -euo pipefail
: "${RG:?source scripts/00-prereqs.sh first}"

echo "==> Resource group"
az group create -n "$RG" -l "$LOCATION" -o none

echo "==> VNet + subnet (so the whole platform lives on your network)"
az network vnet create -g "$RG" -n "$VNET" \
  --address-prefixes 10.42.0.0/16 \
  --subnet-name "$SUBNET" --subnet-prefixes 10.42.1.0/24 -o none
SUBNET_ID=$(az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n "$SUBNET" --query id -o tsv)

echo "==> Container registry (optional, for a custom image)"
az acr create -g "$RG" -n "$ACR" --sku Standard -o none

echo "==> AKS control plane + CPU system pool"
az aks create \
  --resource-group "$RG" --name "$AKS" \
  --location "$LOCATION" \
  --node-count 2 --node-vm-size Standard_D4s_v5 \
  --nodepool-name system \
  --vnet-subnet-id "$SUBNET_ID" \
  --network-plugin azure --network-policy azure \
  --enable-cluster-autoscaler --min-count 1 --max-count 3 \
  --enable-managed-identity \
  --enable-addons azure-keyvault-secrets-provider \
  --enable-secret-rotation \
  --attach-acr "$ACR" \
  --generate-ssh-keys \
  -o none
# For a fully private API server, add: --enable-private-cluster

echo "==> GPU node pool (tainted so only vLLM lands here; scales to zero when idle)"
az aks nodepool add \
  --resource-group "$RG" --cluster-name "$AKS" \
  --name gpupool \
  --node-vm-size "$GPU_VM" \
  --node-count 1 \
  --enable-cluster-autoscaler --min-count 0 --max-count 3 \
  --node-osdisk-size 256 \
  --node-taints "sku=gpu:NoSchedule" \
  --labels nodepool=gpu \
  -o none
# AKS installs the matching NVIDIA driver on the GPU image automatically.
# If you prefer the NVIDIA GPU Operator to manage drivers, add
# --skip-gpu-driver-install and install the operator via Helm instead.

echo "==> Pull kubeconfig"
az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing
kubectl get nodes -o wide
