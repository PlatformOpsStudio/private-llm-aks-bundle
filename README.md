# Private LLM Platform on AKS — Source

Companion code for the article *Build a Private LLM Platform on Azure AKS with vLLM on GPU Nodes*.

## Layout

```
scripts/
  00-prereqs.sh          # login, variables, GPU quota check  (run with: source)
  01-create-aks.sh       # RG, VNet, AKS, tainted GPU node pool
  02-cluster-addons.sh   # device plugin, internal ingress, KEDA, Prometheus, Key Vault
k8s/
  nvidia-device-plugin.yaml
  00-namespace.yaml
  01-secretprovider.yaml # Key Vault -> k8s Secret (fill in the 3 placeholders)
  02-pvc.yaml            # shared model cache
  03-deployment.yaml     # the vLLM server
  04-service-ingress.yaml
  05-keda-scaledobject.yaml
  06-servicemonitor.yaml
  07-embeddings-deployment.yaml  # RAG: embedding model
terraform/               # IaC alternative to the scripts
observability/
  grafana-vllm-dashboard.json   # import into Grafana
client/
  test_client.py         # OpenAI SDK smoke test
  rag_example.py         # embed -> retrieve -> generate
Dockerfile               # optional custom image
PROMO.md                 # LinkedIn + X copy
```

## Quick start

```bash
source scripts/00-prereqs.sh      # edit the vars at the top first
./scripts/01-create-aks.sh
./scripts/02-cluster-addons.sh    # note the keyvaultName / clientID / tenantId it prints

# fill those three values into k8s/01-secretprovider.yaml, then:
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-secretprovider.yaml
kubectl apply -f k8s/02-pvc.yaml
kubectl apply -f k8s/03-deployment.yaml
kubectl apply -f k8s/04-service-ingress.yaml
kubectl apply -f k8s/05-keda-scaledobject.yaml
kubectl apply -f k8s/06-servicemonitor.yaml
kubectl apply -f k8s/07-embeddings-deployment.yaml   # optional: RAG embeddings

kubectl -n llm rollout status deploy/vllm --timeout=15m
```

## Test

```bash
pip install -r client/requirements.txt
export VLLM_API_KEY="$(az keyvault secret show --vault-name <kv> --name vllm-api-key --query value -o tsv)"
export VLLM_BASE_URL="http://llm.internal.example.com/v1"
python client/test_client.py
```

## Notes
- Pin the `vllm/vllm-openai` image tag to a version you have tested.
- `Llama-3.1-8B-Instruct` is gated; accept the license on Hugging Face and store a valid token, or swap to `Qwen/Qwen2.5-7B-Instruct` (ungated).
- The GPU pool is tainted `sku=gpu:NoSchedule` and can scale to zero. Expect a cold start (node provision + model load) on the first request after idle.
