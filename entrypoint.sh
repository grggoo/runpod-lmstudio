#!/usr/bin/env bash
set -euo pipefail

MODEL_FILE="${MODEL_FILE:-/workspace/models/model.gguf}"
LMSTUDIO_PORT="${LMSTUDIO_PORT:-1234}"
MODEL_IDENTIFIER="${MODEL_IDENTIFIER:-qwen35}"
GPU_OFFLOAD="${GPU_OFFLOAD:-max}"
CONTEXT_LENGTH="${CONTEXT_LENGTH:-131072}"
MODEL_TTL="${MODEL_TTL:-3600}"
LINK_DEVICE_NAME="${LINK_DEVICE_NAME:-Runpod LM Studio}"

mkdir -p /workspace/logs
mkdir -p /workspace/models

if [ ! -f "$MODEL_FILE" ]; then
  echo "[FATAL] MODEL_FILE not found: $MODEL_FILE" >&2
  exit 1
fi

echo "[INFO] Starting LM Studio daemon..."
lms daemon up

echo "[INFO] Setting LM Link device name (optional)..."
lms link set-device-name "$LINK_DEVICE_NAME" || true

echo "[INFO] Loading model..."
lms load "$MODEL_FILE" \
  --identifier "$MODEL_IDENTIFIER" \
  --gpu "$GPU_OFFLOAD" \
  --context-length "$CONTEXT_LENGTH" \
  --ttl "$MODEL_TTL"

echo "[INFO] Starting LM Studio server on port $LMSTUDIO_PORT..."
exec lms server start --port "$LMSTUDIO_PORT"
