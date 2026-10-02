#!/usr/bin/env python3
"""
Smoke-test the private vLLM endpoint with the standard OpenAI SDK.
Because vLLM speaks the OpenAI API, any OpenAI-compatible client/library works.

    pip install -r requirements.txt
    export VLLM_API_KEY="<the key you stored in Key Vault>"
    export VLLM_BASE_URL="http://llm.internal.example.com/v1"   # your internal ingress
    python test_client.py
"""
import os
from openai import OpenAI

client = OpenAI(
    base_url=os.environ.get("VLLM_BASE_URL", "http://localhost:8000/v1"),
    api_key=os.environ["VLLM_API_KEY"],
)

MODEL = "llama3.1-8b"   # matches --served-model-name in the deployment


def non_streaming():
    print("\n=== non-streaming ===")
    resp = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": "You are a terse DevOps assistant."},
            {"role": "user", "content": "In one sentence, what is continuous batching?"},
        ],
        temperature=0.2,
        max_tokens=120,
    )
    print(resp.choices[0].message.content)
    print("usage:", resp.usage)


def streaming():
    print("\n=== streaming ===")
    stream = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": "List 3 reasons to self-host an LLM."}],
        stream=True,
        max_tokens=200,
    )
    for chunk in stream:
        delta = chunk.choices[0].delta.content or ""
        print(delta, end="", flush=True)
    print()


if __name__ == "__main__":
    # Confirm the server is up and advertising our model.
    print("models:", [m.id for m in client.models.list().data])
    non_streaming()
    streaming()
