#!/bin/bash
export BRANCH_ID=${BRANCH_ID:-main}
export PLATFORM_ID="RUNPOD"
export TORCH_FORCE_WEIGHTS_ONLY_LOAD=1

export PORT=8000
export HOST="0.0.0.0"
export UI_TYPE="COMFY"
export PROGRAM_PATH=
export RESOURCE_PATH=${RESOURCE_PATH:-"/notebooks/my-runpod-volume/models"}
export LOG_PATH=${LOG_PATH:-"/notebooks/backend.log"}
export PROGRAM_LOG=${PROGRAM_LOG:-"/notebooks/comfy.log"}
export JUPYTER_LAB_PORT=${JUPYTER_LAB_PORT:-"8888"}
export OUTPUT_PATH=${OUTPUT_PATH:-"/notebooks/output_images"}

export CMD=${CMD:-"python -u main.py --listen 0.0.0.0 --disable-auto-launch --output-directory /notebooks/output_images/"}

touch_file() {
    touch $LOG_PATH
    touch $PROGRAM_LOG
}

start_nginx() {
    echo "Start NGINX"
    service nginx start
}

configure_dns() {
    echo "Configuring DNS settings..."
    # Backup the current resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.backup
    # Use Google's public DNS servers
    echo "nameserver 8.8.8.8
nameserver 8.8.4.4" >/etc/resolv.conf
    echo "DNS configuration updated."
}

# Download notebooks
download_notebooks() {
    echo Updating Notebook...
    # curl -s https://raw.githubusercontent.com/vjumpkung/vjump-runpod-notebooks-and-script/refs/heads/$BRANCH_ID/start_comfyui_here.ipynb >start_comfyui_here.ipynb
    cd /notebooks/ && curl -s https://raw.githubusercontent.com/vjumpkung/vjump-runpod-notebooks-and-script/refs/heads/$BRANCH_ID/resource_manager.ipynb >resource_manager.ipynb
    cd /notebooks/ && curl -s https://raw.githubusercontent.com/vjumpkung/vjump-runpod-notebooks-and-script/refs/heads/$BRANCH_ID/ui/main.py >./ui/main.py
    cd /notebooks/ && curl -s https://raw.githubusercontent.com/vjumpkung/vjump-runpod-notebooks-and-script/refs/heads/$BRANCH_ID/ui/google_drive_download.py >./ui/google_drive_download.py
    echo Update Nobebook Completed.
}

update_backend() {
    cd /notebooks/program/vjumpkung-sd-ui-manager-backend/ && git pull --ff-only
}

download_model() {
    if [[ -z $PRE_DOWNLOAD_MODEL_URL ]]; then
        echo "No PRE_DOWNLOAD_MODEL_URL provided skip download" | tee -a $PROGRAM_LOG
    else
        cd /notebooks/
        python pre_download_model.py --input $PRE_DOWNLOAD_MODEL_URL | tee -a $PROGRAM_LOG
    fi
}

# Start jupyter lab
start_jupyter() {
    echo "Starting Jupyter Lab..."
    cd /notebooks/ &&
        nohup jupyter lab \
            --allow-root \
            --ip=0.0.0.0 \
            --no-browser \
            --ServerApp.trust_xheaders=True \
            --ServerApp.disable_check_xsrf=False \
            --ServerApp.allow_remote_access=True \
            --ServerApp.allow_origin='*' \
            --ServerApp.allow_credentials=True \
            --FileContentsManager.delete_to_trash=False \
            --FileContentsManager.always_delete_dir=True \
            --FileContentsManager.preferred_dir=/notebooks \
            --ContentsManager.allow_hidden=True \
            --LabServerApp.copy_absolute_path=True \
            --ServerApp.token='' \
            --ServerApp.password='' &>./jupyter.log &
    echo "Jupyter Lab started"
}

start_comfyui() {
    echo "Starting ComfyUI..."
    /bin/bash /notebooks/start_process.sh &
    echo "ComfyUI Started"
}

start_backend() {
    echo "Starting Resource Manager WebUI..." | tee -a $PROGRAM_LOG
    cd /notebooks/program/vjumpkung-sd-ui-manager-backend && nohup python main.py | tee -a $LOG_PATH &
    echo "Resource Manager WebUI Started" | tee -a $PROGRAM_LOG
}

# Export env vars
export_env_vars() {
    echo "Exporting environment variables..."
    printenv | grep -E '^RUNPOD_|^PATH=|^_=' | awk -F = '{ print "export " $1 "=\"" $2 "\"" }' >>/etc/rp_environment
    echo 'source /etc/rp_environment' >>~/.bashrc
}

make_directory() {
    echo "create directory at $RESOURCE_PATH and output path at $OUTPUT_PATH" | tee -a $PROGRAM_LOG
    mkdir -p $RESOURCE_PATH/{ultralytics_bbox,CatVTON,LLM,animatediff_models,animatediff_motion_lora,ckpts,clip,clip_vision,configs,controlnet,diffusers,diffusion_models,embeddings,facedetection,facerestore_models,gligen,grounding-dino,hypernetworks,insightface,ipadapter,loras,mmdets,nsfw_detector,onnx,photomaker,reactor,rembg,reswapper,sam2,sams,style_models,text_encoders,ultralytics,unet,upscale_models,vae,vae_approx}
    mkdir -p $OUTPUT_PATH
}

run_custom_script() {
    curl -s https://raw.githubusercontent.com/vjumpkung/vjump-runpod-notebooks-and-script/refs/heads/$BRANCH_ID/custom_script.sh -sSf | bash -s -- -y | tee -a $PROGRAM_LOG
}

print_nvidia_gpu() {
    cd /notebooks/ && /bin/bash gpu_info.sh | tee -a $PROGRAM_LOG
}

make_directory
export_env_vars
touch_file
print_nvidia_gpu
configure_dns
update_backend
start_nginx
start_backend
start_jupyter
download_model
download_notebooks
run_custom_script
start_comfyui
echo "Start script(s) finished, pod is ready to use."
sleep infinity
