#!/usr/bin/env python3
"""
Minimal RAG loop against the private platform: embed -> retrieve -> generate.
Uses an in-memory cosine search to stay dependency-light; swap `retrieve()` for
Qdrant / pgvector / Azure AI Search in production.

    pip install openai numpy
    export VLLM_API_KEY=...        # the key from Key Vault
    export LLM_URL=http://llm.internal.example.com/v1
    export EMB_URL=http://vllm-embeddings.llm.svc.cluster.local/v1   # in-cluster
    python rag_example.py
"""
import os, numpy as np
from openai import OpenAI

key = os.environ["VLLM_API_KEY"]
llm = OpenAI(base_url=os.environ.get("LLM_URL", "http://localhost:8000/v1"), api_key=key)
emb = OpenAI(base_url=os.environ.get("EMB_URL", "http://localhost:8001/v1"), api_key=key)

# Your "knowledge base". In reality these come from chunked documents.
DOCS = [
    "The GPU node pool is tainted sku=gpu:NoSchedule so only vLLM lands on it.",
    "vLLM pre-allocates GPU memory for the KV cache, controlled by --gpu-memory-utilization.",
    "The internal ingress has no public IP; it is reachable only over the VPN.",
    "Scaling the GPU pool to zero saves money but adds a multi-minute cold start.",
]

def embed(texts):
    r = emb.embeddings.create(model="bge-large", input=texts)
    return np.array([d.embedding for d in r.data])

DOC_VECS = embed(DOCS)

def retrieve(question, k=2):
    qv = embed([question])[0]
    sims = DOC_VECS @ qv / (np.linalg.norm(DOC_VECS, axis=1) * np.linalg.norm(qv))
    return [DOCS[i] for i in sims.argsort()[::-1][:k]]

def ask(question):
    context = "\n".join(f"- {c}" for c in retrieve(question))
    resp = llm.chat.completions.create(
        model="llama3.1-8b",
        messages=[
            {"role": "system",
             "content": "Answer using ONLY the context. If it isn't there, say so."},
            {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {question}"},
        ],
        temperature=0.1,
    )
    return resp.choices[0].message.content

if __name__ == "__main__":
    print(ask("Why won't random pods run on the GPU nodes?"))
