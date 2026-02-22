import runpod
import requests
import time
import os
import boto3
from botocore.client import Config
from requests.exceptions import ConnectionError, RequestException

# Configurações do ComfyUI
COMFY_URL = "http://127.0.0.1:8188/prompt"
COMFY_HISTORY_URL = "http://127.0.0.1:8188/history"

# Configurações do Backblaze B2 (use ENV vars no RunPod Endpoint)
B2_KEY_ID = os.environ.get('B2_KEY_ID')
B2_APP_KEY = os.environ.get('B2_APP_KEY')
B2_BUCKET = os.environ.get('B2_BUCKET')
B2_ENDPOINT = os.environ.get('B2_ENDPOINT')

# Cliente S3 para Backblaze B2
s3_client = boto3.client(
    's3',
    endpoint_url=B2_ENDPOINT,
    aws_access_key_id=B2_KEY_ID,
    aws_secret_access_key=B2_APP_KEY,
    config=Config(signature_version='s3v4')
)

def is_comfy_ready():
    """Checa se ComfyUI tá respondendo (poll simples em /prompt GET)"""
    try:
        response = requests.get(COMFY_URL, timeout=5)
        return response.status_code == 200
    except ConnectionError:
        return False

def handler(job):
    # Verifica creds do B2
    if not all([B2_KEY_ID, B2_APP_KEY, B2_BUCKET, B2_ENDPOINT]):
        return {"status": "error", "message": "Backblaze B2 credentials not set."}

    payload = job["input"]

    # Espera ComfyUI bootar (retry loop)
    max_wait = 60  # Segundos max (aumente se cold starts forem lentos)
    wait_interval = 2
    waited = 0
    while not is_comfy_ready() and waited < max_wait:
        time.sleep(wait_interval)
        waited += wait_interval

    if not is_comfy_ready():
        return {"status": "error", "message": "ComfyUI not ready after timeout."}

    # Envia o workflow
    try:
        response = requests.post(COMFY_URL, json=payload, timeout=30)
        response.raise_for_status()
        result = response.json()
        prompt_id = result["prompt_id"]
    except RequestException as e:
        return {"status": "error", "message": f"Failed to submit workflow: {str(e)}"}

    # Polling pra esperar terminar
    history = None
    max_attempts = 300  # ~5 min
    attempt = 0
    while history is None and attempt < max_attempts:
        try:
            r = requests.get(f"{COMFY_HISTORY_URL}/{prompt_id}", timeout=10)
            r.raise_for_status()
            h = r.json()
            if prompt_id in h:
                history = h[prompt_id]
        except RequestException:
            pass
        time.sleep(1)
        attempt += 1

    if history is None:
        return {"status": "error", "message": "Timeout waiting for workflow."}

    # Pega output do node 17 (ajuste se o node ID mudar)
    outputs = history.get("outputs", {})
    if "17" not in outputs or "videos" not in outputs["17"]:
        return {"status": "error", "message": "No video in node 17."}

    video_info = outputs["17"]["videos"][0]
    filename = video_info["filename"]
    subfolder = video_info.get("subfolder", "")
    file_path = os.path.join("/comfyui/output", subfolder, filename)  # Ajuste se output for em /runpod-volume

    if not os.path.exists(file_path):
        return {"status": "error", "message": f"File not found: {file_path}"}

    # Upload pro B2
    try:
        s3_key = f"comfy-videos/{filename}"
        with open(file_path, "rb") as f:
            s3_client.upload_fileobj(f, B2_BUCKET, s3_key)

        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': B2_BUCKET, 'Key': s3_key},
            ExpiresIn=3600
        )

        # Opcional: delete local
        # os.remove(file_path)

        return {
            "status": "success",
            "filename": filename,
            "download_url": presigned_url,
            "expires_in_seconds": 3600
        }
    except Exception as e:
        return {"status": "error", "message": f"Upload failed: {str(e)}"}

runpod.serverless.start({"handler": handler})
