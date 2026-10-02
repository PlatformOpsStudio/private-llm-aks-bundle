# OPTIONAL. You usually don't need this — the stock vllm/vllm-openai image is
# fine. Build a custom image only if you want to bake in a chat template, extra
# Python deps, or (for air-gapped clusters) the model weights themselves.
FROM vllm/vllm-openai:v0.6.6

# Example: add a dependency your tooling needs
# RUN pip install --no-cache-dir some-extra-package==1.2.3

# Example: bake a custom chat template
# COPY chat_template.jinja /opt/vllm/chat_template.jinja

# The base image already sets the OpenAI server as the entrypoint, so you only
# override CMD args at deploy time (see k8s/03-deployment.yaml).
