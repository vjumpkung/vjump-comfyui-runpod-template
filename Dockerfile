# Stage 1: Base image with common dependencies
FROM nvidia/cuda:13.0.1-base-ubuntu24.04 AS base

ARG PYTHON_VERSION="3.12"
ARG CONTAINER_TIMEZONE=UTC 

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# create notebooks dir
RUN mkdir -p /notebooks /notebooks/program/

# Install basic tools and dependencies first
RUN ln -snf /usr/share/zoneinfo/$CONTAINER_TIMEZONE /etc/localtime && echo $CONTAINER_TIMEZONE > /etc/timezone
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    build-essential \
    aria2 \
    git \
    git-lfs \
    curl \
    wget \
    gcc \
    g++ \
    bash \
    libgl1 \
    software-properties-common \
    nginx \
    ffmpeg \
    libstdc++6 \
    ca-certificates && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install uv first (before Python)
ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh
ENV PATH="/root/.local/bin/:$PATH"

# Use uv to install Python 3.12
RUN uv python install ${PYTHON_VERSION}

# Create a virtual environment and activate it globally
RUN uv venv /opt/venv --python=${PYTHON_VERSION}
ENV PATH="/opt/venv/bin:$PATH"
ENV VIRTUAL_ENV=/opt/venv

# Set up Python symlinks to make it available system-wide (pointing to venv)
RUN ln -sf /opt/venv/bin/python /usr/bin/python && \
    ln -sf /opt/venv/bin/python /usr/bin/python3

# Verify Python installation
RUN python --version && python3 --version

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli JupyterLab and other python packages (no --system needed now)
RUN uv pip install comfy-cli jupyterlab jupyter-archive nbformat \
    jupyterlab-git ipywidgets ipykernel ipython pickleshare "aiofiles==24.1.0" "httpx==0.28.1" python-dotenv uvicorn "rich==14.0.0" fastapi websockets \
    requests python-dotenv nvitop gdown onnxruntime-gpu "numpy<2" imageio-ffmpeg pip && \
    uv cache clean

RUN uv pip install https://huggingface.co/vjump21848/sageattention-pre-compiled-wheel/resolve/main/sageattention-2.2.0-cp312-cp312-linux_x86_64.whl

# Copy reverse proxy config
COPY src/nginx_comfyui_conf.conf /etc/nginx/sites-available/
RUN ln -s /etc/nginx/sites-available/nginx_comfyui_conf.conf /etc/nginx/sites-enabled/

# Install ComfyUI
WORKDIR /notebooks
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /notebooks/ComfyUI
RUN uv pip install torch==2.9.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130
RUN uv pip install -r https://raw.githubusercontent.com/comfyanonymous/ComfyUI/refs/heads/master/requirements.txt
RUN uv pip install -r https://raw.githubusercontent.com/Comfy-Org/ComfyUI-Manager/refs/heads/main/requirements.txt
RUN uv cache clean

WORKDIR /notebooks/ComfyUI/custom_nodes
RUN git clone https://github.com/Comfy-Org/ComfyUI-Manager.git

WORKDIR /notebooks

RUN mkdir -p ./src/ ./ui/

COPY resource_manager.ipynb .
# COPY start_comfyui_here.ipynb .
COPY start.sh .
COPY gpu_info.sh .
COPY start_process.sh .
COPY stop_process.sh .
COPY pre_download_model.py .
COPY cf_tunnel.py .
COPY ui/. ./ui/
COPY src/. ./src/

# copy config.ini
RUN mkdir -p ./ComfyUI/user/default/ComfyUI-Manager

COPY src/config.ini ./ComfyUI/user/default/ComfyUI-Manager/

# copy extra path

WORKDIR /notebooks/ComfyUI

COPY src/extra_model_paths.yaml .

# clone model manager

WORKDIR /notebooks/program/

RUN git clone https://github.com/vjumpkung/vjumpkung-sd-ui-manager-backend.git

WORKDIR /notebooks

EXPOSE 8188 8888 3001 8000
CMD ["jupyter", "lab", "--allow-root", "--ip=0.0.0.0", "--no-browser", \
    "--ServerApp.trust_xheaders=True", "--ServerApp.disable_check_xsrf=False", \
    "--ServerApp.allow_remote_access=True", "--ServerApp.allow_origin='*'", \
    "--ServerApp.allow_credentials=True", "--FileContentsManager.delete_to_trash=False", \
    "--FileContentsManager.always_delete_dir=True", "--FileContentsManager.preferred_dir=/notebooks", \
    "--ContentsManager.allow_hidden=True", "--LabServerApp.copy_absolute_path=True", \
    "--ServerApp.token=''", "--ServerApp.password=''"]