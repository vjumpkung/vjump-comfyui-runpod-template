#!/bin/bash
export BRANCH_ID=${BRANCH_ID:-main}
export PLATFORM_ID="RUNPOD"
export TORCH_FORCE_WEIGHTS_ONLY_LOAD=0
export PYTORCH_ENABLE_UNSAFE_LOAD=1
export PORT=8000
export COMFY_PORT=8188
export HOST="0.0.0.0"
export UI_TYPE="COMFY"
export PROGRAM_PATH=
export RESOURCE_PATH=${RESOURCE_PATH:-"/notebooks/my-runpod-volume/models"}
export LOG_PATH=${LOG_PATH:-"/notebooks/backend.log"}
export PROGRAM_LOG=${PROGRAM_LOG:-"/notebooks/comfy.log"}
export JUPYTER_LAB_PORT=${JUPYTER_LAB_PORT:-"8888"}
export OUTPUT_PATH=${OUTPUT_PATH:-"/notebooks/my-runpod-volume/output_images/"}

export CMD=${CMD:-"python -u main.py --listen 0.0.0.0 --disable-auto-launch --output-directory /notebooks/my-runpod-volume/output_images/ --enable-cors-header --preview-method auto --disable-partner-nodes"}

setup_logging() {
    mkdir -p "$(dirname "$LOG_PATH")" "$(dirname "$PROGRAM_LOG")"
    touch "$LOG_PATH" "$PROGRAM_LOG"
    exec > >(tee -a "$PROGRAM_LOG") 2>&1
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

update_backend() {
    cd /notebooks/program/vjumpkung-sd-ui-manager-backend/ && git pull -q --ff-only && uv pip install -q -r requirements.txt
}

download_model() {
    if [[ -z $PRE_DOWNLOAD_MODEL_URL ]]; then
        echo "No PRE_DOWNLOAD_MODEL_URL provided skip download"
    else
        cd /notebooks/
        python pre_download_model.py --input "$PRE_DOWNLOAD_MODEL_URL"
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
    /bin/bash /notebooks/start_process.sh
    echo "ComfyUI Started"
}

start_backend() {
    echo "Starting Resource Manager WebUI..."
    cd /notebooks/program/vjumpkung-sd-ui-manager-backend && nohup python main.py >>"$LOG_PATH" &
    echo "Resource Manager WebUI Started"
}

# Export env vars
export_env_vars() {
    echo "Exporting environment variables..."
    printenv | grep -E '^RUNPOD_|^PATH=|^_=' | awk -F = '{ print "export " $1 "=\"" $2 "\"" }' >>/etc/rp_environment
    echo 'source /etc/rp_environment' >>~/.bashrc
}

make_directory() {
    echo "create directory at $RESOURCE_PATH and output path at $OUTPUT_PATH"
    mkdir -p "$RESOURCE_PATH"/{LLM,RMBG,animatediff_models,animatediff_motion_lora,audio_encoders,background_removal,blip,checkpoints,clip,clip_vision,configs,controlnet,detection,diffusers,diffusion_models,embeddings,facedetection,facerestore_models,facexlib,frame_interpolation,geometry_estimation,gligen,grounding-dino,hf_cache_dir,hypernetworks,inpaint,insightface,ipadapter,latent_upscale_models,loras,mmdets,model_patches,nsfw_detector,omnivoice,onnx,optical_flow,photomaker,pulid,reactor,rembg,reswapper,sam2,sams,style_models,text_encoders,ultralytics,unet,upscale_models,vae,vae_approx,yolo}
    mkdir -p "$OUTPUT_PATH"
}

run_custom_script() {
    curl -s https://raw.githubusercontent.com/vjumpkung/vjump-runpod-notebooks-and-script/refs/heads/$BRANCH_ID/custom_script.sh -sSf | bash -s -- -y
}

print_nvidia_gpu() {
    cd /notebooks/ && /bin/bash gpu_info.sh
    python -c "import torch; print('CUDA AVAILABLE :',torch.cuda.is_available())"
}

run_cf_tunnel() {
    cd /notebooks/ && nohup python cf_tunnel.py $PORT $COMFY_PORT $JUPYTER_LAB_PORT | tee -a $LOG_PATH &
}

setup_logging
make_directory
export_env_vars
print_nvidia_gpu
configure_dns
update_backend
start_nginx
start_backend
start_jupyter
run_cf_tunnel
download_model
run_custom_script
start_comfyui
sleep infinity
