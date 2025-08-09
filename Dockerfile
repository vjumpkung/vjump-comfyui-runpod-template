# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.8.1-base-ubuntu22.04 AS base

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

# Install Python, git and other necessary tools
RUN ln -snf /usr/share/zoneinfo/$CONTAINER_TIMEZONE /etc/localtime && echo $CONTAINER_TIMEZONE > /etc/timezone
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends build-essential aria2 git git-lfs curl wget gcc g++ bash libgl1 software-properties-common nginx ffmpeg && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update --yes && \
    apt-get install --yes --no-install-recommends "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" "python${PYTHON_VERSION}-tk" && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Set up Python and pip
RUN ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    rm /usr/bin/python3 && \
    ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python get-pip.py

# add uv

# The installer requires curl (and certificates) to download the release archive
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates

# Download the latest installer
ADD https://astral.sh/uv/install.sh /uv-installer.sh

# Run the installer then remove it
RUN sh /uv-installer.sh && rm /uv-installer.sh

# Ensure the installed binary is on the `PATH`
ENV PATH="/root/.local/bin/:$PATH"

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli JupyterLab and other python packages
RUN uv pip install --system comfy-cli jupyterlab jupyter-archive nbformat \
    jupyterlab-git ipywidgets ipykernel ipython pickleshare "aiofiles==24.1.0" "httpx==0.28.1" python-dotenv uvicorn "rich==14.0.0" fastapi websockets \
    requests python-dotenv nvitop gdown onnxruntime-gpu "numpy<2" imageio-ffmpeg && \ 
    uv pip install --system https://huggingface.co/Kijai/PrecompiledWheels/resolve/main/sageattention-2.2.0-cp312-cp312-linux_x86_64.whl && \
    uv cache clean

# Copy reverse proxy config
COPY src/nginx_comfyui_conf.conf /etc/nginx/sites-available/
RUN ln -s /etc/nginx/sites-available/nginx_comfyui_conf.conf /etc/nginx/sites-enabled/

# Install ComfyUI
WORKDIR /notebooks
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /notebooks/ComfyUI
RUN uv pip install --system torch==2.7.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
RUN uv pip install --system -r https://raw.githubusercontent.com/comfyanonymous/ComfyUI/refs/heads/master/requirements.txt
RUN uv pip install --system -r https://raw.githubusercontent.com/Comfy-Org/ComfyUI-Manager/refs/heads/main/requirements.txt
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



