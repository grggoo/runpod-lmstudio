#!/usr/bin/env bash
set -euo pipefail

MODELS_DIR="${MODELS_DIR:-/workspace/models}"
MODEL_FILE="${MODEL_FILE:-}"
MMPROJ_FILE="${MMPROJ_FILE:-}"
LMSTUDIO_PORT="${LMSTUDIO_PORT:-1234}"
LMSTUDIO_BIND="${LMSTUDIO_BIND:-0.0.0.0}"
LMSTUDIO_CORS="${LMSTUDIO_CORS:-1}"
MODEL_IDENTIFIER="${MODEL_IDENTIFIER:-}"
GPU_OFFLOAD="${GPU_OFFLOAD:-max}"
CONTEXT_LENGTH="${CONTEXT_LENGTH:-131072}"
PARALLEL="${PARALLEL:-1}"
MODEL_TTL="${MODEL_TTL:-3600}"
LINK_DEVICE_NAME="${LINK_DEVICE_NAME:-Runpod LM Studio}"
LINK_ENABLE="${LINK_ENABLE:-1}"
USER_REPO="${USER_REPO:-runpod}"
LMSTUDIO_HOME_PERSIST="${LMSTUDIO_HOME_PERSIST:-/workspace/.lmstudio}"
LMSTUDIO_FORCE_REINIT="${LMSTUDIO_FORCE_REINIT:-0}"

mkdir -p /workspace/logs "$MODELS_DIR"

if [ "$LMSTUDIO_FORCE_REINIT" = "1" ] && [ -d "$LMSTUDIO_HOME_PERSIST" ]; then
  echo "[INFO] LMSTUDIO_FORCE_REINIT=1 -> wiping $LMSTUDIO_HOME_PERSIST"
  rm -rf "$LMSTUDIO_HOME_PERSIST"
fi

if [ ! -e "$LMSTUDIO_HOME_PERSIST" ]; then
  echo "[INFO] First run: seeding persistent LM Studio home at $LMSTUDIO_HOME_PERSIST"
  mkdir -p "$LMSTUDIO_HOME_PERSIST"
  if [ -d /root/.lmstudio ] && [ ! -L /root/.lmstudio ]; then
    cp -a /root/.lmstudio/. "$LMSTUDIO_HOME_PERSIST"/
  fi
fi

if [ ! -L /root/.lmstudio ]; then
  echo "[INFO] Linking /root/.lmstudio -> $LMSTUDIO_HOME_PERSIST"
  rm -rf /root/.lmstudio
  ln -s "$LMSTUDIO_HOME_PERSIST" /root/.lmstudio
fi

echo "[INFO] Starting LM Studio daemon..."
lms daemon up
sleep 5

if [ "$LINK_ENABLE" = "1" ]; then
  echo "[INFO] Enabling LM Link as '$LINK_DEVICE_NAME' (best-effort, requires prior 'lms login')..."
  lms link enable || true
  lms link set-device-name "$LINK_DEVICE_NAME" || true
fi

if [ -z "$MODEL_FILE" ]; then
  for f in "$MODELS_DIR"/*.gguf; do
    [ -e "$f" ] || continue
    case "$f" in
      *mmproj*) ;;
      *) MODEL_FILE="$f"; break ;;
    esac
  done
fi
if [ -z "$MMPROJ_FILE" ]; then
  for f in "$MODELS_DIR"/*mmproj*.gguf; do
    [ -e "$f" ] || continue
    MMPROJ_FILE="$f"; break
  done
fi

if [ -n "$MODEL_FILE" ] && [ -f "$MODEL_FILE" ]; then
  BASE="$(basename "$MODEL_FILE" .gguf)"
  if [ -z "$MODEL_IDENTIFIER" ]; then
    MODEL_IDENTIFIER="$(echo "$BASE" | tr '[:upper:]' '[:lower:]')"
  fi

  echo "[INFO] Importing main model: $MODEL_FILE -> $USER_REPO/$BASE"
  lms import --symbolic-link -y --user-repo "$USER_REPO/$BASE" "$MODEL_FILE" || true
  if [ -n "$MMPROJ_FILE" ] && [ -f "$MMPROJ_FILE" ]; then
    echo "[INFO] Importing mmproj: $MMPROJ_FILE"
    lms import --symbolic-link -y --user-repo "$USER_REPO/$BASE" "$MMPROJ_FILE" || true
  fi

  echo "[INFO] Loading $BASE as '$MODEL_IDENTIFIER' (gpu=$GPU_OFFLOAD ctx=$CONTEXT_LENGTH parallel=$PARALLEL ttl=$MODEL_TTL)"
  lms unload "$MODEL_IDENTIFIER" >/dev/null 2>&1 || true
  lms load "$BASE" \
    --identifier "$MODEL_IDENTIFIER" \
    --gpu "$GPU_OFFLOAD" \
    --context-length "$CONTEXT_LENGTH" \
    --parallel "$PARALLEL" \
    --ttl "$MODEL_TTL" \
    -y || echo "[WARN] lms load failed; server will still start"
else
  echo "[WARN] No GGUF found in $MODELS_DIR. Server will start without preloaded model."
fi

SERVER_ARGS=(--port "$LMSTUDIO_PORT" --bind "$LMSTUDIO_BIND")
if [ "$LMSTUDIO_CORS" = "1" ]; then
  SERVER_ARGS+=(--cors)
fi

echo "[INFO] Starting LM Studio server: lms server start ${SERVER_ARGS[*]}"
lms server start "${SERVER_ARGS[@]}"

echo "[INFO] Server up. Tailing daemon (container stays alive)."
exec tail -f /dev/null
