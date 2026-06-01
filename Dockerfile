# ==========================================
# Phase 1: Build & Sync
# ==========================================
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

# Prevent prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install core build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install uv (Astral's lightning-fast package manager)
ADD https://astral.sh/uv/install.sh /install.sh
RUN chmod +x /install.sh && /install.sh && rm /install.sh
ENV PATH="/root/.local/bin:${PATH}"

# Configure uv to use standalone python build
ENV UV_PYTHON_INSTALL_DIR="/app/python"
RUN uv python install 3.11

WORKDIR /app

# Clone public repos into vendor/ (as setup.sh normally does)
RUN git clone https://github.com/PrismML-Eng/image-studio.git vendor/image-studio \
    && git clone https://github.com/PrismML-Eng/mflux-prism.git vendor/mflux-prism

# Patch image-studio's pyproject.toml to match local sibling vendor layout
RUN sed -i 's|^mflux = { git = .*$|mflux = { path = "../mflux-prism", editable = true }|' vendor/image-studio/pyproject.toml

# Copy project specification files for uv dependency resolution
COPY pyproject.toml uv.lock ./

# Create virtual environment and synchronize dependencies (locked to sys_platform == linux)
RUN uv venv .venv --python 3.11 \
    && uv sync --frozen

# Install frontend dependencies inside image-studio frontend checkout at build time
RUN cd vendor/image-studio/frontend \
    && npm install --no-audit --no-fund

# Copy the core scripts, setup, and readmes
COPY scripts/ ./scripts/
COPY README.md setup.sh ./

# ==========================================
# Phase 2: Runtime Environment
# ==========================================
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS runner

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install lightweight runtime utilities, build-essential, and nodejs for Triton's JIT and Next.js execution
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    build-essential \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Copy built application and virtual environment from Stage 1
COPY --from=builder /app /app
COPY --from=builder /root/.local /root/.local

# Set path environment variables
ENV PATH="/app/.venv/bin:/root/.local/bin:${PATH}"

# Expose backend and frontend ports
EXPOSE 8000
EXPOSE 3000

# Copy and set execution permissions for the entrypoint
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
