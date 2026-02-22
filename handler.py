import runpod
import requests
import time
import os
import boto3
from botocore.client import Config
from requests.exceptions import ConnectionError, RequestException, HTTPError

# Configurações do ComfyUI
COMFY_URL = "http://127.0.0.1:8188/prompt"
COMFY_HISTORY_URL = "http://127.0.0.1:8188/history"

# Configurações do Backblaze B2 (via ENV vars no RunPod)
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
    """Checa se ComfyUI está respondendo"""
    try:
        response = requests.get(COMFY_URL, timeout=5)
        return response.status_code == 200
    except ConnectionError:
        return False

def handler(job):
    # Verifica credenciais B2
    if not all([B2_KEY_ID, B2_APP_KEY, B2_BUCKET, B2_ENDPOINT]):
        return {"status": "error", "message": "Backblaze B2 credentials not set."}

    input_data = job["input"]
    print("Input recebido do job:", input_data)

    # Ajusta o payload para o formato esperado pelo ComfyUI (/prompt)
    # Muitos usuários enviam { "workflow": {...} }, então ajustamos aqui
    payload = {"prompt": input_data.get("workflow", input_data)}
    print("Payload ajustado enviado para /prompt:", payload)

    # Espera ComfyUI estar pronto (aumentei um pouco o timeout para cold starts)
    max_wait = 120
    wait_interval = 3
    waited = 0
    while not is_comfy_ready() and waited < max_wait:
        time.sleep(wait_interval)
        waited += wait_interval

    if not is_comfy_ready():
        return {"status": "error", "message": "ComfyUI not ready after timeout."}

    # Envia o workflow
    try:
        response = requests.post(COMFY_URL, json=payload, timeout=60)
        response.raise_for_status()
        result = response.json()
        print("Resposta do /prompt:", result)
        prompt_id = result.get("prompt_id")
        if not prompt_id:
            return {"status": "error", "message": "No prompt_id in response"}
    except HTTPError as http_err:
        error_msg = f"HTTP {response.status_code}: {response.text}"
        print("Erro HTTP ao submeter workflow:", error_msg)
        return {"status": "error", "message": f"Failed to submit workflow: {error_msg}"}
    except RequestException as e:
        print("Erro na requisição:", str(e))
        return {"status": "error", "message": f"Failed to submit workflow: {str(e)}"}

    # Polling para esperar o workflow terminar
    history = None
    max_attempts = 600  # ~10 min
    attempt = 0
    while history is None and attempt < max_attempts:
        try:
            r = requests.get(f"{COMFY_HISTORY_URL}/{prompt_id}", timeout=10)
            r.raise_for_status()
            h = r.json()
            if prompt_id in h:
                history = h[prompt_id]
                print("Workflow concluído. History:", history)
        except RequestException:
            pass
        time.sleep(1)
        attempt += 1

    if history is None:
        return {"status": "error", "message": "Timeout waiting for workflow."}

    # Extrai o vídeo do node 17 (VHS_VideoCombine)
    outputs = history.get("outputs", {})
    if "17" not in outputs or "videos" not in outputs["17"]:
        return {"status": "error", "message": "No video found in node 17 outputs."}

    video_info = outputs["17"]["videos"][0]
    filename = video_info["filename"]
    subfolder = video_info.get("subfolder", "")
    file_path = os.path.join("/comfyui/output", subfolder, filename)

    if not os.path.exists(file_path):
        return {"status": "error", "message": f"File not found: {file_path}"}

    # Upload para Backblaze B2
    try:
        s3_key = f"comfy-videos/{filename}"
        with open(file_path, "rb") as f:
            s3_client.upload_fileobj(f, B2_BUCKET, s3_key)

        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': B2_BUCKET, 'Key': s3_key},
            ExpiresIn=3600
        )

        print("Upload concluído. URL gerada:", presigned_url)

        return {
            "status": "success",
            "filename": filename,
            "download_url": presigned_url,
            "expires_in_seconds": 3600
        }
    except Exception as e:
        print("Erro no upload:", str(e))
        return {"status": "error", "message": f"Upload failed: {str(e)}"}

runpod.serverless.start({"handler": handler})
