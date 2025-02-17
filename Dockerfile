# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04 as base

ARG PYTHON_VERSION="3.10"
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
RUN mkdir -p /notebooks /comfyui_setup_temp

# Install Python, git and other necessary tools
RUN ln -snf /usr/share/zoneinfo/$CONTAINER_TIMEZONE /etc/localtime && echo $CONTAINER_TIMEZONE > /etc/timezone
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends build-essential aria2 git git-lfs curl wget gcc g++ bash libgl1 software-properties-common&& \
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

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli
RUN pip install comfy-cli
# JupyterLab and other python packages
RUN pip install --no-cache-dir jupyterlab jupyter-archive nbformat \
    jupyterlab-git ipywidgets ipykernel ipython pickleshare \
    requests python-dotenv nvitop gdown && \
    pip install --no-cache-dir "numpy<2" && \
    pip cache purge

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /notebooks/ComfyUI install --cuda-version 12.4 --nvidia --version 0.3.14

# restore snapshot

WORKDIR /comfyui_setup_temp

COPY src/snapshot.json .

RUN comfy --workspace /notebooks/ComfyUI node restore-snapshot snapshot.json --pip-non-url

WORKDIR /notebooks

RUN mkdir -p ./src/ ./ui/

COPY resource_manager.ipynb .
COPY start_comfyui_here.ipynb .
COPY start.sh .
COPY pre_download_model.py .
COPY ui/. ./ui/
COPY src/. ./src/

WORKDIR /notebooks/ComfyUI

COPY src/extra_model_paths.yaml .

WORKDIR /notebooks

EXPOSE 8188 8888
CMD ["jupyter", "lab", "--allow-root", "--ip=0.0.0.0", "--no-browser", \
    "--ServerApp.trust_xheaders=True", "--ServerApp.disable_check_xsrf=False", \
    "--ServerApp.allow_remote_access=True", "--ServerApp.allow_origin='*'", \
    "--ServerApp.allow_credentials=True", "--FileContentsManager.delete_to_trash=False", \
    "--FileContentsManager.always_delete_dir=True", "--FileContentsManager.preferred_dir=/notebooks", \
    "--ContentsManager.allow_hidden=True", "--LabServerApp.copy_absolute_path=True", \
    "--ServerApp.token=''", "--ServerApp.password=''"]



