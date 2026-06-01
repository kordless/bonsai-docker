# Bonsai Docker 🌸🐳

A premium, fully self-contained Docker environment for building and running **Bonsai Image 4B**—the state-of-the-art, GPU-accelerated ternary/binary image generation stack.

This repository bundles both the **FastAPI GPU backend (Uvicorn)** and the **Next.js Visual Studio Frontend** in a single, high-performance containerized system, complete with Triton JIT compiler support.

---

## ⚡ Quick Start

### 1. Host Requirements
Ensure your host machine (Windows/Linux) has:
* **Docker** & **Docker Compose** installed.
* **NVIDIA Container Toolkit** installed and configured (to enable GPU orchestration inside Docker).
* **NVIDIA GPU Driver** (supporting CUDA 12+).

### 2. Start the Unified Container
Initialize and run the container system:
```bash
docker compose up -d
```
This automatically builds the runtime environment and launches both services concurrently in the background:
* 🎨 **Visual Studio UI**: [http://localhost:3000/](http://localhost:3000/) — Open this in your browser to start generating!
* 🔌 **FastAPI Backend Docs**: [http://localhost:8000/docs](http://localhost:8000/docs)
* 🟢 **Backend Healthcheck**: [http://localhost:8000/healthz](http://localhost:8000/healthz)

### 3. Download the Model Weights
Weights are downloaded directly inside the container and cached on your host via volume mounts. Run whichever you prefer (or both):
```bash
# Recommended: Download the high-quality 1.58-bit Ternary model (~1.21GB)
docker exec -it bonsai-image-4b-endpoint ./scripts/download_model.sh --model ternary-gemlite

# Optional: Download the ultra-compact 1-bit Binary model (~0.93GB)
docker exec -it bonsai-image-4b-endpoint ./scripts/download_model.sh --model binary-gemlite
```

---

## ⚙️ Configuration

You can customize the container's execution via the environment variables defined in [`docker-compose.yml`](file:///workspace/bonsai-image-endpoint/docker-compose.yml):

| Environment Variable | Allowed Values | Default | Description |
|---|---|---|---|
| `BONSAI_VARIANT` | `ternary` / `binary` | `ternary` | Selects which variant model the FastAPI Uvicorn engine serves. |
| `BONSAI_WARMUP_SHAPES` | e.g. `512x512` | `512x512` | Pre-compiles and autotunes Triton kernels for these shapes at container startup. |
| `HF_HUB_ENABLE_HF_TRANSFER` | `0` / `1` | `1` | Enables high-speed parallel range-request HuggingFace snapshot downloading. |

---

## 🛠️ CLI Operations Inside Docker

You can run internal tooling commands on the active container using `docker exec`:

### Run a One-Shot Image Generation
```bash
docker exec -it bonsai-image-4b-endpoint ./scripts/generate.sh --prompt "An icy Bonsai tree, in a rainy forest with snowy mountains in the background, photorealistic" --output outputs/icy_bonsai.png
```

### Warm Up Warm/Warm-Reload Models
```bash
docker exec -it bonsai-image-4b-endpoint ./scripts/send_request.sh -p "An icy Bonsai tree..." --size 512x512
```

### Run Backend Client Smoke Tests
```bash
docker exec -it bonsai-image-4b-endpoint python3 test_client.py
```

---

## 📂 Preserved Volume Mounts
The container maps two local directories on your host to avoid data loss across container teardowns:
* `./models` ➔ `/app/models` — Saves downloaded model checkpoints.
* `./outputs` ➔ `/app/outputs` — Saves generated images, Triton JIT compile kernels, and Gemlite autotuner cache directories.
