# Promo copy

## LinkedIn post

"Legal won't let us send customer data to a hosted LLM. Can we run our own?"

I hear this almost every week — so I wrote the whole build-along.

A fully private LLM platform on Azure AKS, with vLLM serving an open-weights model on a GPU node pool that lives entirely inside your own VNet. OpenAI-compatible endpoint, so your devs change exactly one line: the base URL. Nothing leaves your network.

The article covers the parts the docs skip:
→ GPU quota reality (check it before you write any config)
→ The NVIDIA device-plugin gotcha that eats everyone's first afternoon
→ Secrets via Key Vault + CSI (no tokens in Git)
→ Model caching so cold starts are seconds, not minutes
→ The /dev/shm and gpu-memory-utilization traps in the vLLM deployment
→ Autoscaling on queue depth (CPU-based HPA is useless for GPUs)
→ Scale-to-zero vs. cost vs. cold starts — the real trade-off
→ Observability + a ready-to-import Grafana dashboard
→ A RAG appendix: add an embedding model and you've got the serving half of a RAG stack

Full source included — scripts, manifests, Terraform, and a test client. Clone it, change the variables, serve traffic this afternoon.

Link in comments. 👇

#Azure #Kubernetes #AKS #vLLM #LLM #MLOps #DevOps #GPU #SelfHosting

---

## X / Twitter thread

1/
Everyone wants a private LLM. Almost nobody wants to debug GPU scheduling on Kubernetes at 11pm.

So here's the whole thing, done right: a private LLM platform on Azure AKS with vLLM on GPU nodes — inside your own VNet, OpenAI-compatible, nothing leaving your network. 🧵

2/
The architecture in one line: a tainted GPU node pool runs vLLM and ONLY vLLM. Everything else (ingress, monitoring, autoscaler) stays on cheap CPU nodes. GPUs are too expensive to share with a logging sidecar.

3/
The gotcha that eats your first afternoon:
Your GPU node is up, the driver is installed, and k8s STILL says there's no GPU.

Missing piece: the NVIDIA device plugin. AKS installs the driver, not the plugin. And the stock manifest won't tolerate your taint.

4/
Secrets: HF token + API key go in Key Vault, surfaced to the pod via the Secrets Store CSI driver. Nothing sensitive in Git. The sync only fires when a pod actually MOUNTS the CSI volume — easy to miss.

5/
Two traps in the vLLM deployment itself:
• /dev/shm defaults to 64MB in a container — too small, crashes on tensor parallelism. Back it with memory.
• --gpu-memory-utilization too high = OOM at load, too low = wasted VRAM you paid for.

6/
Autoscaling: CPU-based HPA is useless here (vLLM can pin the GPU while CPU barely moves). Scale on QUEUE DEPTH instead — vllm:num_requests_waiting — via KEDA. Scale-to-zero is great for the bill, brutal for first-request latency.

7/
Bonus: add an embedding model (same vLLM, --task=embed) and a vector DB and you've got the serving half of a RAG stack — all private.

Full guide + source (scripts, manifests, Terraform, Grafana dashboard):
[LINK]
