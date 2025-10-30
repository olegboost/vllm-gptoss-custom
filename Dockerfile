# syntax=docker/dockerfile:1

# Use the official vLLM OpenAI compatibility image as the base to ensure
# parity with the vanilla deployment experience.
FROM vllm/vllm-openai:latest

# Install the GPT-OSS compatible vLLM build with the recommended CUDA wheels.
RUN uv pip install --pre "vllm==0.10.1+gptoss" \
    --extra-index-url https://wheels.vllm.ai/gpt-oss/ \
    --extra-index-url https://download.pytorch.org/whl/nightly/cu128 \
    --index-strategy unsafe-best-match

# Default to running the openai/gpt-oss-20b model. This value can be
# overridden at runtime through the MODEL_NAME environment variable.
ENV MODEL_NAME="openai/gpt-oss-20b"
# When MODEL_PATH is provided it takes precedence over MODEL_NAME and is
# expected to point to a local filesystem path (e.g. a mounted volume).
ENV MODEL_PATH=""

# Allow tuning of commonly customised server level settings via
# environment variables. These match the behaviour of the upstream
# vllm-openai container but default to values that work in Kubernetes.
ENV HOST=0.0.0.0 \
    PORT=8000 \
    WORKER_CONCURRENCY=1 \
    TENSOR_PARALLEL_SIZE=1 \
    PIPELINE_PARALLEL_SIZE=1 \
    MAX_NUM_SEQS=256 \
    SERVED_MODEL_NAME="" \
    TRUST_REMOTE_CODE="false" \
    DTYPE="auto" \
    LOAD_FORMAT="auto" \
    VLLM_EXTRA_ARGS="" \
    OPENAI_API_KEY="" \
    DEBUG_ENTRYPOINT="false"

# Provide a wrapper entrypoint that translates the above environment
# variables into arguments for the vLLM OpenAI-compatible API server.
COPY docker/entrypoint.sh /opt/vllm/entrypoint.sh
RUN chmod +x /opt/vllm/entrypoint.sh

ENTRYPOINT ["/opt/vllm/entrypoint.sh"]
CMD []
