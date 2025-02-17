import ipywidgets as widgets
from IPython.display import display
import subprocess
import os
import shlex
import zipfile
import requests
import torch


platform_id = "OTHER"

if "RUNPOD_POD_ID" in os.environ.keys():
    platform_id = "RUNPOD"
elif "PAPERSPACE_FQDN" in os.environ.keys():
    platform_id = "PAPERSPACE"


class Envs:
    def __init__(self):
        self.CIVITAI_TOKEN = ""
        self.HUGGINGFACE_TOKEN = ""


envs = Envs()

model_url = "https://gist.githubusercontent.com/vjumpkung/4663f8a608699ac80f1769a6bd0daee4/raw/9f3411a6eb51bd4244bb655bee8b458330284f89/vjump_notebook_model_template.json"
clip_vae_url = "https://gist.githubusercontent.com/vjumpkung/421667857264bc11686cb28026f374dd/raw/6210ee04b03f362043ccc1c2974d8d3df7da26b6/vjump_notebook_clipvae.json"


def get_model_list():

    r = requests.get(model_url)

    data = r.json()

    return data


def get_clip_list():

    r = requests.get(clip_vae_url)

    data = r.json()

    return data


def test():
    status_header = widgets.HTML('<h2 style="width: 250px;">Import สำเร็จ!</h2>')
    headers = widgets.HBox([status_header])
    display(headers)


def setup():

    if not torch.cuda.is_available():
        warn = widgets.HTML('<h3 style="width: 500px;">ไม่พบ CUDA โปรดสร้าง Pod ใหม่</h3>')
        headers = widgets.HBox([warn])
        display(headers)
    else:
        warn = widgets.HTML('<h3 style="width: 500px;">พบ CUDA :)</h3>')
        headers = widgets.HBox([warn])
        display(headers)

    settings = []
    input_list = [
        ("CIVITAI_TOKEN", "CivitAI API Key", "Paste your API key here", ""),
        ("HUGGINGFACE_TOKEN", "Huggingface API Key", "Paste your API key here", ""),
    ]

    save_button = widgets.Button(description="Save", button_style="primary")
    output = widgets.Output()

    for key, input_label, placeholder, input_value in input_list:
        label = widgets.Label(input_label, layout=widgets.Layout(width="100px"))
        textfield = widgets.Text(
            placeholder=placeholder,
            value=input_value,
            layout=widgets.Layout(width="400px"),
        )
        settings.append((key, textfield))
        row = [label, textfield]
        print("")
        display(widgets.HBox(row))

    def on_save(button):
        output.clear_output()
        with output:
            for key, textInput in settings:
                if key == "CIVITAI_TOKEN":
                    envs.CIVITAI_TOKEN = textInput.value
                elif key == "HUGGINGFACE_TOKEN":
                    envs.HUGGINGFACE_TOKEN = textInput.value
            print("\nSaved ✔")

    save_button.on_click(on_save)
    display(save_button, output)


check_types = [
    "CatVTON",
    "LLM",
    "animatediff_models",
    "animatediff_motion_lora",
    "checkpoints",
    "clip",
    "clip_vision",
    "configs",
    "controlnet",
    "diffusers",
    "diffusion_models",
    "embeddings",
    "facedetection",
    "facerestore_models",
    "gligen",
    "grounding-dino",
    "hypernetworks",
    "insightface",
    "ipadapter",
    "loras",
    "mmdets",
    "nsfw_detector",
    "onnx",
    "photomaker",
    "reactor",
    "rembg",
    "reswapper",
    "sam2",
    "sams",
    "style_models",
    "text_encoders",
    "ultralytics",
    "unet",
    "upscale_models",
    "vae",
    "vae_approx",
]


def download(name: str, url: str, type: str):

    if type not in check_types:
        print("Invalid Model Type")
        return

    destination = ""
    filename = ""

    if type == "checkpoints":
        type = "ckpts"

    destination = f"./my-runpod-volume/models/{type}/"

    print(f"Starting download: {name}")

    if envs.CIVITAI_TOKEN != "":
        if "?" in url:
            url += f"&token={envs.CIVITAI_TOKEN}"
        else:
            url += f"?token={envs.CIVITAI_TOKEN}"

    command = f"aria2c --console-log-level=error -c -x 16 -s 16 -k 1M {url} --dir={destination} --download-result=hide"

    if envs.HUGGINGFACE_TOKEN != "":
        command += f' --header="Authorization: Bearer {envs.HUGGINGFACE_TOKEN}"'

    if "huggingface" in url:
        filename = url.split("/")[-1]
        command += f" -o {filename}"

    if "civitai" in url:
        command += " --content-disposition=true"

    if "drive.google.com" in url:
        command = (
            f"python ./ui/google_drive_download.py --path {destination} --url {url}"
        )

    with subprocess.Popen(
        shlex.split(command),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    ) as sp:
        print("\033[?25l", end="")
        for line in sp.stdout:
            if line.startswith("[#"):
                text = "Download progress {}".format(line.strip("\n"))
                print("\r" + " " * 100 + "\r" + text, end="", flush=True)
                prev_line = text
            elif line.startswith("[COMPLETED]"):
                if prev_line != "":
                    print("", flush=True)
            else:
                print(line.strip(), end="", flush=True)
        print("\033[?25h")

    print(f"Download completed: {name}")


def download_models():
    models_header = widgets.HTML(
        '<h4 style="width: auto;">Download Model จาก Google Drive, CivitAI หรือ Huggingface</h4>'
    )
    display(models_header)

    description = widgets.Label(
        "Please Select type (โปรดเลือกประเภทของ Model ก่อน Download)"
    )
    model_type = widgets.Dropdown(
        options=check_types,
        value="checkpoints",
        disabled=False,
    )
    title = widgets.Label(
        "Model Type (ประเภทของโมเดล) :", layout=widgets.Layout(width="auto")
    )
    display(description)
    dropdown = widgets.HBox([title, model_type])
    display(dropdown)

    textinputlayout = widgets.Layout(width="400px", height="40px")
    url_model = widgets.Text(
        value="",
        placeholder="Paste Huggingface or CivitAI model here",
        disabled=False,
        layout=textinputlayout,
    )
    textWidget = widgets.HBox([widgets.Label("Model url:"), url_model])

    display(textWidget)

    download_button = widgets.Button(description="Download", button_style="primary")
    output = widgets.Output()

    def on_press(button):
        with output:
            output.clear_output()
            try:
                if url_model.value != "":
                    download(
                        f"Download {model_type.value} : ",
                        url_model.value,
                        model_type.value,
                    )

                completed_message()

            except KeyboardInterrupt:
                print("\n\n--Download Model interrupted--")

    download_button.on_click(on_press)

    display(download_button, output)


def completed_message():
    completed = widgets.Button(
        description="Completed", button_style="success", icon="check"
    )
    print("\n")
    display(completed)


def launch_comfyui():

    models_header = widgets.HTML(
        '<h3 style="width: 250px;">เริ่มโปรแกรม ComfyUI ตรงนี้</h3>'
    )
    display(models_header)
    output = widgets.Output()

    def run_gui(button):

        os.chdir("/notebooks/")

        command = "python -u main.py --listen 0.0.0.0 --disable-auto-launch"

        if platform_id == "RUNPOD":
            proxy_url = f'URL : https://{os.environ.get("RUNPOD_POD_ID")}-{8188}.proxy.runpod.net'
        elif platform_id == "PAPERSPACE":
            proxy_url = f'URL : https://tensorboard-{os.environ.get("PAPERSPACE_FQDN")}'

        os.chdir("/notebooks/ComfyUI/")  # Change to the ComfyUI directory

        try:
            # Start the subprocess with unbuffered output
            process = subprocess.Popen(
                shlex.split(command),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,  # Line buffering
            )

            with output:
                output.clear_output()
                print("kohya-ss GUI has been started see logs at console")
                print(proxy_url)

                for i in process.stdout:
                    print(i.strip())

            # Wait for the subprocess to complete
            process.wait()

        except KeyboardInterrupt:
            process.terminate()
            with output:
                print("\n--Process terminated--")
        finally:
            os.chdir("/notebooks/")  # Restore the working directory

    start_button = widgets.Button(description="START ComfyUI", button_style="primary")

    start_button.on_click(run_gui)

    display(start_button, output)
