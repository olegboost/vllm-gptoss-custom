#!/usr/bin/env bash
set -euo pipefail

# Allow people to opt-in to bash debugging.
if [[ "${DEBUG_ENTRYPOINT:-false}" == "true" ]]; then
  set -x
fi

HOST=${HOST:-0.0.0.0}
PORT=${PORT:-8000}
MODEL_NAME=${MODEL_NAME:-openai/gpt-oss-20b}
MODEL_PATH=${MODEL_PATH:-}
WORKER_CONCURRENCY=${WORKER_CONCURRENCY:-1}
TENSOR_PARALLEL_SIZE=${TENSOR_PARALLEL_SIZE:-1}
PIPELINE_PARALLEL_SIZE=${PIPELINE_PARALLEL_SIZE:-1}
MAX_NUM_SEQS=${MAX_NUM_SEQS:-256}
SERVED_MODEL_NAME=${SERVED_MODEL_NAME:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}
TRUST_REMOTE_CODE=${TRUST_REMOTE_CODE:-false}
DTYPE=${DTYPE:-auto}
LOAD_FORMAT=${LOAD_FORMAT:-auto}
VLLM_EXTRA_ARGS=${VLLM_EXTRA_ARGS:-}

if [[ -n "$MODEL_PATH" ]]; then
  MODEL_TARGET="$MODEL_PATH"
else
  MODEL_TARGET="$MODEL_NAME"
fi

ARGS=(
  "python3"
  "-m" "vllm.entrypoints.openai.api_server"
  "--host" "$HOST"
  "--port" "$PORT"
  "--model" "$MODEL_TARGET"
  "--tensor-parallel-size" "$TENSOR_PARALLEL_SIZE"
  "--pipeline-parallel-size" "$PIPELINE_PARALLEL_SIZE"
  "--max-num-seqs" "$MAX_NUM_SEQS"
  "--dtype" "$DTYPE"
  "--load-format" "$LOAD_FORMAT"
)

if [[ -n "$WORKER_CONCURRENCY" ]]; then
  ARGS+=("--worker-concurrency" "$WORKER_CONCURRENCY")
fi

if [[ "$TRUST_REMOTE_CODE" == "true" ]]; then
  ARGS+=("--trust-remote-code")
fi

if [[ -n "$SERVED_MODEL_NAME" ]]; then
  ARGS+=("--served-model-name" "$SERVED_MODEL_NAME")
fi

if [[ -n "$OPENAI_API_KEY" ]]; then
  ARGS+=("--api-key" "$OPENAI_API_KEY")
fi

# shellcheck disable=SC2206 # We need word splitting for user supplied args.
if [[ -n "$VLLM_EXTRA_ARGS" ]]; then
  EXTRA=( $VLLM_EXTRA_ARGS )
  ARGS+=("${EXTRA[@]}")
fi

# Allow users to pass additional flags via the container CMD/args.
if [[ $# -gt 0 ]]; then
  ARGS+=("$@")
fi

exec "${ARGS[@]}"
