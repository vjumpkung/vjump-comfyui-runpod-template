import argparse
import os
import shlex
import subprocess
import sys

import requests

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


class Envs:
    def __init__(self):
        self.CIVITAI_TOKEN = ""
        self.HUGGINGFACE_TOKEN = ""

    def get_enviroment_variable(self):
        if "CIVITAI_TOKEN" in os.environ.keys() and self.CIVITAI_TOKEN == "":
            self.CIVITAI_TOKEN = os.environ["CIVITAI_TOKEN"]
        if "HUGGINGFACE_TOKEN" in os.environ.keys() and self.HUGGINGFACE_TOKEN == "":
            self.HUGGINGFACE_TOKEN = os.environ["HUGGINGFACE_TOKEN"]


def download(name: str, url: str, type: str):
    if "envs" not in globals():
        global envs
        envs = Envs()
        envs.get_enviroment_variable()

    if type not in check_types:
        print("Invalid Model Type")
        return sys.exit(1)

    destination = ""
    filename = ""

    if type == "checkpoints":
        type = "ckpts"

    destination = f"./my-runpod-volume/models/{type}/"

    print(f"Starting download: {name}\n")

    if "civitai" in url and envs.CIVITAI_TOKEN != "":
        if "?" in url:
            url += f"&token={envs.CIVITAI_TOKEN}"
        else:
            url += f"?token={envs.CIVITAI_TOKEN}"

    command = f"aria2c --console-log-level=error -c -x 16 -s 16 -k 1M {url} --dir={destination} --download-result=hide"

    if "huggingface" in url and envs.HUGGINGFACE_TOKEN != "":
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

    process_success = True
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
                print(line.strip(), flush=True)
        print("\033[?25h")

        # Check the return code of the process
        return_code = sp.wait()
        if return_code != 0:
            process_success = False

    if process_success:
        print(f"Download completed: {name}")
        return 0
    else:
        print(f"Download failed: {name}")
        return sys.exit(1)


def get_model_list(url: str):
    return requests.get(url).json()


def main(args):
    url = args.input
    try:
        if url:
            downloads_list = get_model_list(url)
            for i in downloads_list:
                download(
                    i["name"],
                    i["url"],
                    i["type"],
                )
            print("Pre-Download Model Complete")
        else:
            print("no download url provided")
            return
    except:
        exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Pre Download Models")
    parser.add_argument("-i", "--input", required=True, help="URL")
    args = parser.parse_args()
    main(args)
