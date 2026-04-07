# LM Studio headless on CUDA 12.4 — no GGUF inside image; mount RunPod Network Volume on /workspace.
#
# Build:
#   cd runpod-lmstudio
#   docker build -t grishagrok/llm:cuda12.4 .
#
# Login & push (create repo grishagrok/llm on Docker Hub if needed):
#   docker login --username grishagrok
#   docker push grishagrok/llm:cuda12.4
#
# Smoke test (no GPU):
#   docker run --rm --entrypoint bash grishagrok/llm:cuda12.4 -lc 'which lms && lms --help | head -5'

FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.lmstudio/bin:/root/.local/bin:${PATH}"

RUN apt-get update && apt-get install -y \
    bash \
    curl \
    ca-certificates \
    tini \
    jq \
    libatomic1 \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Install LM Studio headless runtime / CLI
RUN curl -fsSL https://lmstudio.ai/install.sh | bash

# Simple sanity check
RUN lms --help >/dev/null

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1234

ENTRYPOINT ["/usr/bin/tini", "-s", "--", "/entrypoint.sh"]
