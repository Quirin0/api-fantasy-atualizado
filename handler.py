import runpod
import requests
import base64
import os

COMFY_URL = "http://127.0.0.1:8188/prompt"

def handler(job):
    payload = job["input"]

    # envia workflow para o ComfyUI interno
    response = requests.post(COMFY_URL, json=payload)
    result = response.json()

    # espera terminar (simples polling)
    prompt_id = result["prompt_id"]

    history = None
    while history is None:
        r = requests.get(f"http://127.0.0.1:8188/history/{prompt_id}")
        h = r.json()
        if prompt_id in h:
            history = h[prompt_id]

    # pega node 17 (VHS_VideoCombine)
    outputs = history["outputs"]
    video_info = outputs["17"]["videos"][0]
    filename = video_info["filename"]

    file_path = f"/comfyui/output/{filename}"

    with open(file_path, "rb") as f:
        video_base64 = base64.b64encode(f.read()).decode("utf-8")

    return {
        "status": "success",
        "filename": filename,
        "video_base64": video_base64
    }

runpod.serverless.start({"handler": handler})