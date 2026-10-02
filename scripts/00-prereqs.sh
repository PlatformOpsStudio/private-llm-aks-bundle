#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 00-prereqs.sh — log in, set variables, and sanity-check GPU quota.
# Run with:  source scripts/00-prereqs.sh   (so the vars stay in your shell)
# ---------------------------------------------------------------------------
set -euo pipefail

# --- edit these -----------------------------------------------------------
export LOCATION="eastus2"                       # pick a region that has A100 quota
export RG="rg-private-llm"
export AKS="aks-private-llm"
export VNET="vnet-llm"
export SUBNET="snet-aks"
export ACR="acrprivatellm$RANDOM"               # must be globally unique
export KEYVAULT="kv-llm-$RANDOM"                 # must be globally unique
export GPU_VM="Standard_NC24ads_A100_v4"        # 1x A100 80GB. NV36ads_A10_v5 is cheaper.
export GPU_QUOTA_FAMILY="standardNCADSA100v4Family"
# --------------------------------------------------------------------------

echo "Logging in..."
az login --only-show-errors >/dev/null
az account show --query '{subscription:name, id:id}' -o table

echo "Registering providers (idempotent)..."
az provider register --namespace Microsoft.ContainerService --wait
az provider register --namespace Microsoft.KeyVault --wait

echo "Checking GPU quota for $GPU_VM in $LOCATION ..."
az vm list-usage --location "$LOCATION" -o table \
  | grep -i "$GPU_QUOTA_FAMILY" || {
    echo "!! No quota row found. Request a quota increase for $GPU_QUOTA_FAMILY before continuing."
    echo "   Portal > Subscriptions > Usage + quotas, or: az quota ..."
  }

echo "Done. Variables exported for the rest of the scripts."
