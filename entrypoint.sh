#!/bin/bash
# ==============================================================================
#   Bonsai Image 4B Container entrypoint.sh
# ==============================================================================
set -e

DEMO_DIR="/app"
cd "$DEMO_DIR"

echo "========================================================"
echo "    Bonsai Image 4B Endpoint Bootloader"
echo "========================================================"
echo ""

# 1. Verify GPU/CUDA accessibility inside the container environment
echo "Checking GPU / CUDA status..."
python3 -c "import torch; print('  PyTorch CUDA Available:', torch.cuda.is_available()); print('  Device Count:', torch.cuda.device_count())"
echo ""

# 2. Set default model variant (ternary [default, high-quality] or binary [compact])
: "${BONSAI_VARIANT:=ternary}"
echo "Selected Bonsai variant: ${BONSAI_VARIANT}"

# Validate variant choice
case "$BONSAI_VARIANT" in
    ternary|binary) ;;
    *) echo "Error: BONSAI_VARIANT must be 'ternary' or 'binary' (got $BONSAI_VARIANT)" >&2; exit 1 ;;
esac

# 3. Resolve paths
_model_dir="$DEMO_DIR/models/bonsai-image-4B-${BONSAI_VARIANT}-gemlite"
_ternary_dir="$DEMO_DIR/models/bonsai-image-4B-ternary-gemlite"
_binary_dir="$DEMO_DIR/models/bonsai-image-4B-binary-gemlite"

# Check if the active variant has its transformer folder downloaded
_active_transformer=$(ls -d "$_model_dir"/transformer-gemlite-* 2>/dev/null | head -1 || true)

if [ -z "$_active_transformer" ]; then
    echo "--------------------------------------------------------"
    echo " Model files for variant '${BONSAI_VARIANT}' not found in /app/models."
    echo " Automatically initiating HuggingFace download..."
    echo " (This might take several minutes on first startup)"
    echo "--------------------------------------------------------"
    # Execute the download script using the active python virtualenv environment
    ./scripts/download_model.sh --model "${BONSAI_VARIANT}-gemlite"
fi

# Re-resolve the downloaded transformer paths for environment setups
_ternary_transformer=$(ls -d "$_ternary_dir"/transformer-gemlite-* 2>/dev/null | head -1 || true)
_binary_transformer=$(ls -d "$_binary_dir"/transformer-gemlite-* 2>/dev/null | head -1 || true)

# Ensure the launched variant's transformer exists
_launched_transformer=$(ls -d "$_model_dir"/transformer-gemlite-* 2>/dev/null | head -1 || true)
if [ -z "$_launched_transformer" ]; then
    echo "Error: Failed to find or download transformer files under ${_model_dir}." >&2
    exit 1
fi

# Define uvicorn launch arguments
_default_backend="bonsai-${BONSAI_VARIANT}-gemlite"
_backend_module="scripts.local_backend:app"

# Export the paths exactly as expected by backend_gpu.pipeline_gpu
export MFLUX_STUDIO_GPU_DEFAULT_BACKEND="$_default_backend"
export MFLUX_STUDIO_GPU_TEXT_ENCODER_PATH="$_model_dir/text_encoder-hqq-4bit"
export MFLUX_STUDIO_GPU_VAE_PATH="$_model_dir/vae"
export MFLUX_STUDIO_GPU_TOKENIZER_PATH="$_model_dir/text_encoder-hqq-4bit/tokenizer"

# Always export both transformer paths as expected by GpuPipeline on boot, falling back to nominal paths if missing
export MFLUX_STUDIO_GPU_TERNARY_TRANSFORMER_PATH="${_ternary_transformer:-$_ternary_dir/transformer-gemlite-int2}"
export MFLUX_STUDIO_GPU_BINARY_TRANSFORMER_PATH="${_binary_transformer:-$_binary_dir/transformer-gemlite-int1}"

echo "--------------------------------------------------------"
echo " Starting Next.js Frontend..."
echo " Interface: http://0.0.0.0:3000"
echo " NEXT_PUBLIC_BACKEND_URL: http://localhost:8000"
echo "--------------------------------------------------------"
echo ""

# Launch Next.js dev server in the background
cd /app/vendor/image-studio/frontend
PORT=3000 HOSTNAME=0.0.0.0 NEXT_PUBLIC_BACKEND_URL="http://localhost:8000" npm run dev &
cd /app

echo "--------------------------------------------------------"
echo " Starting FastAPI / Uvicorn Server..."
echo " Default Backend: ${_default_backend}"
echo " Interface: 0.0.0.0:8000"
echo "--------------------------------------------------------"
echo ""

# Start the uvicorn daemon
exec uvicorn "$_backend_module" --host 0.0.0.0 --port 8000
