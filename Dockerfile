# syntax=docker/dockerfile:1

ARG UV_VERSION=0.12.3
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM nvidia/cuda:13.0.3-base-ubuntu24.04 AS runtime

ARG PYTHON_VERSION=3.12
ARG CONTAINER_TIMEZONE=UTC
ARG DEBIAN_FRONTEND=noninteractive

ENV PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    UV_LINK_MODE=copy \
    UV_PYTHON_CACHE_DIR=/root/.cache/uv/python \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:${PATH}"

# Install uv from Astral's official, version-pinned distroless image.
COPY --from=uv /uv /uvx /usr/local/bin/

RUN ln -snf "/usr/share/zoneinfo/${CONTAINER_TIMEZONE}" /etc/localtime && \
    echo "${CONTAINER_TIMEZONE}" > /etc/timezone && \
    apt-get update && \
    apt-get install --yes --no-install-recommends \
        aria2 \
        bash \
        build-essential \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        git-lfs \
        libgl1 \
        nginx \
        wget && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* && \
    mkdir -p /notebooks/program /notebooks/ui

# Persist downloaded Python in the BuildKit cache while copying the environment
# files into the image, so rebuilds are fast without retaining uv's package cache.
RUN --mount=type=cache,id=uv-cache,target=/root/.cache/uv \
    uv python install "${PYTHON_VERSION}" && \
    uv venv "${VIRTUAL_ENV}" --python "${PYTHON_VERSION}" && \
    ln -sf "${VIRTUAL_ENV}/bin/python" /usr/bin/python && \
    ln -sf "${VIRTUAL_ENV}/bin/python" /usr/bin/python3 && \
    python --version && \
    uv --version

COPY src/nginx_comfyui_conf.conf /etc/nginx/sites-available/nginx_comfyui_conf.conf
RUN ln -s /etc/nginx/sites-available/nginx_comfyui_conf.conf /etc/nginx/sites-enabled/nginx_comfyui_conf.conf

# Shallow clones retain normal pull/update support while excluding repository history.
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /notebooks/ComfyUI && \
    git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git /notebooks/ComfyUI/custom_nodes/ComfyUI-Manager && \
    git clone --depth=1 https://github.com/vjumpkung/vjumpkung-sd-ui-manager-backend.git /notebooks/program/vjumpkung-sd-ui-manager-backend

WORKDIR /notebooks/ComfyUI

# Keep every Python installation in one image layer. The cache and local wheel are
# BuildKit mounts, so neither download archives nor the 32 MB wheel enter the image.
RUN --mount=type=cache,id=uv-cache,target=/root/.cache/uv \
    --mount=type=bind,source=src/sageattention-2.2.0+cu130.torch210.sm80.86.89.120-cp312-cp312-linux_x86_64.whl,target=/tmp/sageattention-2.2.0+cu130.torch210.sm80.86.89.120-cp312-cp312-linux_x86_64.whl \
    uv pip install \
        comfy-cli \
        jupyterlab \
        jupyter-archive \
        nbformat \
        jupyterlab-git \
        ipywidgets \
        ipykernel \
        ipython \
        pickleshare \
        "aiofiles==24.1.0" \
        "httpx==0.28.1" \
        python-dotenv \
        uvicorn \
        "rich==14.0.0" \
        fastapi \
        websockets \
        requests \
        nvitop \
        gdown \
        "numpy<2.3" \
        imageio-ffmpeg \
        pip && \
    uv pip install \
        torch==2.10.0 \
        torchvision==0.25.0 \
        torchaudio==2.10.0 \
        --index-url https://download.pytorch.org/whl/cu130 && \
    uv pip install -r requirements.txt && \
    uv pip install -r custom_nodes/ComfyUI-Manager/requirements.txt && \
    uv pip install /tmp/sageattention-2.2.0+cu130.torch210.sm80.86.89.120-cp312-cp312-linux_x86_64.whl && \
    uv pip install https://github.com/JamePeng/llama-cpp-python/releases/download/v0.3.34-cu130-Basic-linux-20260331/llama_cpp_python-0.3.34+cu130.basic-cp312-cp312-linux_x86_64.whl && \
    uv pip install https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.9.0/flash_attn-2.8.3+cu130torch2.10-cp312-cp312-linux_x86_64.whl && \
    uv pip install https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.8.2/flash_attn_3-3.0.0+cu130torch2.10gite2743ab-cp39-abi3-linux_x86_64.whl && \
    uv pip install \
        --pre \
        --index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/ort-cuda-13-nightly/pypi/simple/ \
        onnxruntime-gpu && \
    uv pip install \
        https://github.com/vjumpkung/vjump-runpod-notebooks-and-script/raw/refs/heads/main/trellis_2_wheels/cumesh-1.0-cp312-cp312-linux_x86_64.whl \
        https://github.com/vjumpkung/vjump-runpod-notebooks-and-script/raw/refs/heads/main/trellis_2_wheels/flex_gemm-1.0.0-cp312-cp312-linux_x86_64.whl \
        https://github.com/vjumpkung/vjump-runpod-notebooks-and-script/raw/refs/heads/main/trellis_2_wheels/nvdiffrast-0.4.0-cp312-cp312-linux_x86_64.whl \
        https://github.com/vjumpkung/vjump-runpod-notebooks-and-script/raw/refs/heads/main/trellis_2_wheels/nvdiffrec_render-0.0.0-cp312-cp312-linux_x86_64.whl \
        https://github.com/vjumpkung/vjump-runpod-notebooks-and-script/raw/refs/heads/main/trellis_2_wheels/o_voxel-0.0.1-cp312-cp312-linux_x86_64.whl && \
    uv pip install natten==0.21.6+torch2100cu130 -f https://whl.natten.org && \
    uv pip list

WORKDIR /notebooks

COPY start.sh gpu_info.sh start_process.sh stop_process.sh pre_download_model.py cf_tunnel.py ./
COPY ui/ ./ui/
COPY src/config.ini ./ComfyUI/user/__manager__/config.ini
COPY src/extra_model_paths.yaml ./ComfyUI/extra_model_paths.yaml

EXPOSE 8188 8888 3001 8000

CMD ["/bin/bash", "start.sh"]
