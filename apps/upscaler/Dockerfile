# syntax=docker/dockerfile:1

# Use the official uv image with Python 3.13
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

# Set working directory
WORKDIR /app

# Enable bytecode compilation for better performance
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Install dependencies first (separate layer for better caching)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

# Copy the project source code
COPY . /app

# Install the project itself (without editable mode for production)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev --no-editable

# Final stage - minimal runtime image
FROM python:3.13-slim-bookworm

# torch's ROCm wheels link against OpenMP and libnuma at import time
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 libnuma1 \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security. GPU access comes from the supplementary
# render/video groups the compose file adds, so root is not required.
RUN groupadd -r appuser \
    && useradd -r -g appuser -m -d /home/appuser appuser \
    && mkdir -p /home/appuser/.cache \
    && chown -R appuser:appuser /home/appuser

# Docker does not read HOME from /etc/passwd; without this the MIOpen kernel
# cache lands in / rather than the volume mounted at /home/appuser/.cache.
ENV HOME=/home/appuser

# Set working directory
WORKDIR /app

# Copy the virtual environment from builder
COPY --from=builder --chown=appuser:appuser /app/.venv /app/.venv
COPY --from=builder --chown=appuser:appuser /app/logging.json ./

# Place the virtual environment at the front of the PATH
ENV PATH="/app/.venv/bin:$PATH"

# Fail the build rather than a request if the CUDA wheel displaced the ROCm one
RUN python -c "import torch, spandrel; assert torch.version.hip, f'not a ROCm build: {torch.__version__}'; print(torch.__version__, torch.version.hip, spandrel.__version__)"

# Switch to non-root user
USER appuser

# Expose the application port
EXPOSE 8700

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8700/healthz')" || exit 1

# Run the application
CMD ["uvicorn", "upscaler.app:app", "--host", "0.0.0.0", "--port", "8700", "--log-config", "logging.json"]
