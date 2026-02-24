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

# Configurações do Backblaze B2
B2_KEY_ID = os.environ.get('B2_KEY_ID')
B2_APP_KEY = os.environ.get('B2_APP_KEY')
B2_BUCKET = os.environ.get('B2_BUCKET')
B2_ENDPOINT = os.environ.get('B2_ENDPOINT')

s3_client = boto3.client(
    's3',
    endpoint_url=B2_ENDPOINT,
    aws_access_key_id=B2_KEY_ID,
    aws_secret_access_key=B2_APP_KEY,
    config=Config(signature_version='s3v4')
)

def is_comfy_ready():
    try:
        response = requests.get(COMFY_URL, timeout=5)
        return response.status_code == 200
    except ConnectionError:
        return False

def handler(job):
    if not all([B2_KEY_ID, B2_APP_KEY, B2_BUCKET, B2_ENDPOINT]):
        return {"status": "error", "message": "Backblaze B2 credentials not set."}

    input_data = job["input"]
    print("Input recebido do job:", input_data)

    workflow = input_data.get("workflow", input_data)
    payload = {"prompt": workflow}
    print("Payload ajustado enviado para /prompt:", payload)

    max_wait = 120
    wait_interval = 3
    waited = 0
    while not is_comfy_ready() and waited < max_wait:
        time.sleep(wait_interval)
        waited += wait_interval

    if not is_comfy_ready():
        return {"status": "error", "message": "ComfyUI not ready after timeout."}

    try:
        response = requests.post(COMFY_URL, json=payload, timeout=60)
        response.raise_for_status()
        result = response.json()
        print("Resposta do /prompt:", result)
        prompt_id = result.get("prompt_id")
        if not prompt_id:
            return {"status": "error", "message": "No prompt_id in response"}
    except HTTPError as http_err:
        error_detail = response.text if 'response' in locals() else str(http_err)
        print("HTTP Error ao submeter workflow:", response.status_code, error_detail)
        return {"status": "error", "message": f"Failed to submit workflow: {response.status_code} - {error_detail}"}
    except RequestException as e:
        print("Request Exception:", str(e))
        return {"status": "error", "message": f"Failed to submit workflow: {str(e)}"}

    # Polling history
    history = None
    max_attempts = 600
    attempt = 0
    while history is None and attempt < max_attempts:
        try:
            r = requests.get(f"{COMFY_HISTORY_URL}/{prompt_id}", timeout=10)
            r.raise_for_status()
            h = r.json()
            if prompt_id in h:
                history = h[prompt_id]
                print("Workflow concluído. History keys:", list(history.keys()))
        except RequestException:
            pass
        time.sleep(1)
        attempt += 1

    if history is None:
        return {"status": "error", "message": "Timeout waiting for workflow."}

    # Procura dinamicamente o node que gera o vídeo (VHS_VideoCombine)
    outputs = history.get("outputs", {})
    video_node_id = None
    video_info = None
    filename_prefix = None

    # Lista de class_types que geram vídeo final (adicione mais se precisar)
    video_class_types = ["VHS_VideoCombine", "SaveAnimatedWEBP", "SaveVideo"]

    for node_id, node_data in workflow.items():
        if node_data.get("class_type") in video_class_types:
            video_node_id = node_id
            filename_prefix = node_data.get("inputs", {}).get("filename_prefix", "output_")
            print(f"Node de vídeo encontrado: {node_id} ({node_data['class_type']}), prefix: {filename_prefix}")
            break

    if not video_node_id:
        return {"status": "error", "message": "Nenhum node de vídeo (ex: VHS_VideoCombine) encontrado no workflow."}

    node_output = outputs.get(video_node_id, {})
    print(f"Outputs do node {video_node_id}:", node_output)

    video_filename = None
    subfolder = ""

    # 1. Formato preferido: "videos"
    if "videos" in node_output and node_output["videos"]:
        video_info = node_output["videos"][0]
        video_filename = video_info["filename"]
        subfolder = video_info.get("subfolder", "")
        print(f"Vídeo encontrado em 'videos' do node {video_node_id}: {video_filename}")

    # 2. Formato alternativo: "filenames"
    elif "filenames" in node_output and node_output["filenames"]:
        video_filename = node_output["filenames"][0]
        print(f"Vídeo encontrado em 'filenames' do node {video_node_id}: {video_filename}")

        # 3. Fallback: procura no disco usando o filename_prefix extraído
    else:
        output_dir = "/comfyui/output"
        found_file = None
        for file in os.listdir(output_dir):
            # Procura se o arquivo contém o prefixo (mais flexível)
            if filename_prefix in file and file.lower().endswith((".mp4", ".webm", ".gif", ".mov", ".avi")):
                found_file = file
                print(f"Vídeo encontrado por prefixo contido no disco ({filename_prefix}): {found_file}")
                break

        if found_file:
            video_filename = found_file
        else:
            # Debug extra: lista todos os arquivos em /output para ver o que existe
            all_files = os.listdir(output_dir)
            print(f"Arquivos disponíveis em /comfyui/output: {all_files}")
            return {"status": "error", "message": f"Nenhum arquivo de vídeo encontrado no disco contendo '{filename_prefix}'. Veja lista de arquivos nos logs."}
            
    if not video_filename:
        return {"status": "error", "message": f"Nenhum filename de vídeo encontrado para o node {video_node_id}."}

    file_path = os.path.join("/comfyui/output", subfolder, video_filename)

    if not os.path.exists(file_path):
        return {"status": "error", "message": f"Arquivo não encontrado no disco: {file_path}"}

    # Upload para Backblaze B2
    try:
        s3_key = f"comfy-videos/{video_filename}"
        with open(file_path, "rb") as f:
            s3_client.upload_fileobj(f, B2_BUCKET, s3_key)

        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': B2_BUCKET, 'Key': s3_key},
            ExpiresIn=3600
        )

        print("Upload OK. URL:", presigned_url)

        return {
            "status": "success",
            "filename": video_filename,
            "download_url": presigned_url,
            "expires_in_seconds": 3600
        }
    except Exception as e:
        print("Upload error:", str(e))
        return {"status": "error", "message": f"Upload failed: {str(e)}"}

runpod.serverless.start({"handler": handler})
