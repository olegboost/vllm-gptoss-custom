## Custom vLLM OpenAI-Compatible Image

This repository contains a Docker build context for running
`openai/gpt-oss-20b` with the vanilla `vllm-openai` server interface. The
Dockerfile extends the upstream `vllm/vllm-openai` image, pre-installs the
`vllm==0.10.1+gptoss` wheel (from the official GPT-OSS index plus the CUDA
nightly channel), and ships an entrypoint that converts environment variables
into the right CLI options so that you can mount locally downloaded models and
tune runtime settings without rewriting the image.

### Build the image

```bash
docker build -t my-vllm-gpt-oss-20b .
```

### Run locally

If you already downloaded the model to `/models/openai-gpt-oss-20b`, mount that
path into the container and set `MODEL_PATH` so vLLM loads it from disk instead
of trying to fetch it remotely.

```bash
docker run --gpus all \
  -p 8000:8000 \
  -v /models/openai-gpt-oss-20b:/models/openai-gpt-oss-20b \
  -e MODEL_PATH=/models/openai-gpt-oss-20b \
  my-vllm-gpt-oss-20b
```

Other optional environment variables are exposed to match the upstream image.
For example, to change the listening port and served model name:

```bash
docker run --gpus all \
  -p 9000:9000 \
  -e PORT=9000 \
  -e SERVED_MODEL_NAME=gpt-oss-20b \
  my-vllm-gpt-oss-20b
```

### Deploy on Kubernetes

1. Push the image you built above to a registry accessible by your cluster.
2. Create a `PersistentVolume` (and `PersistentVolumeClaim`) that exposes the
   directory containing the locally downloaded model files.
3. Reference the image and volume from your `Deployment` or `StatefulSet`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpt-oss-20b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gpt-oss-20b
  template:
    metadata:
      labels:
        app: gpt-oss-20b
    spec:
      containers:
        - name: vllm
          image: registry.example.com/my-vllm-gpt-oss-20b:latest
          ports:
            - name: http
              containerPort: 8000
          env:
            - name: MODEL_PATH
              value: /models/openai-gpt-oss-20b
          volumeMounts:
            - name: model-storage
              mountPath: /models/openai-gpt-oss-20b
      volumes:
        - name: model-storage
          persistentVolumeClaim:
            claimName: gpt-oss-20b-model
```

Expose the deployment with a `Service` (e.g. `LoadBalancer` or `ClusterIP`) and
point your clients to `http://<service-host>:<service-port>/v1` just like the
standard `vllm-openai` container.

### Environment variable reference

The entrypoint accepts the following environment variables, mirroring the
upstream image defaults but allowing you to override them at runtime:

| Variable | Description | Default |
| --- | --- | --- |
| `MODEL_NAME` | Hugging Face repo to load when `MODEL_PATH` is not set | `openai/gpt-oss-20b` |
| `MODEL_PATH` | Local filesystem path to a downloaded model | empty |
| `HOST` | Interface for the OpenAI-compatible HTTP server | `0.0.0.0` |
| `PORT` | HTTP port | `8000` |
| `WORKER_CONCURRENCY` | Number of async workers per server | `1` |
| `TENSOR_PARALLEL_SIZE` | Tensor parallelism degree | `1` |
| `PIPELINE_PARALLEL_SIZE` | Pipeline parallelism degree | `1` |
| `MAX_NUM_SEQS` | Maximum concurrent sequences | `256` |
| `SERVED_MODEL_NAME` | Override the model name reported by the API | empty |
| `TRUST_REMOTE_CODE` | Allow custom code execution for the model | `false` |
| `DTYPE` | Model weights data type (`auto`, `half`, etc.) | `auto` |
| `LOAD_FORMAT` | Model loading format | `auto` |
| `VLLM_EXTRA_ARGS` | Additional arguments passed verbatim to the server | empty |
| `OPENAI_API_KEY` | Optional API key to gate requests | empty |
| `DEBUG_ENTRYPOINT` | Set to `true` to echo the constructed command | `false` |

Any extra arguments you provide as `docker run ... my-image --flag value` (or in
the pod spec `args:` list) are appended directly to the `vllm.entrypoints.openai`
command, letting you fine-tune behaviour beyond these environment variables.
