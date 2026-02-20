ARG CACHE_BUST=1

#Base limpa com ComfyUI + comfy-cli + Manager
FROM runpod/worker-comfyui:5.5.1-base

# Atualiza pacotes e instala git/wget se necessário (já tem na base, mas garante)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget curl && \
    rm -rf /var/lib/apt/lists/*

# Instala custom nodes necessários via git clone (principais do seu workflow)
# Rode pip install requirements.txt de cada um para evitar erros de dependências
WORKDIR /comfyui/custom_nodes

RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    cd ComfyUI-VideoHelperSuite && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..

RUN git clone https://github.com/rgthree/rgthree-comfy.git && \
    cd rgthree-comfy && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..

RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    cd ComfyUI-WanVideoWrapper && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..

RUN git clone https://github.com/Smirnov75/ComfyUI-mxToolkit.git

RUN git clone https://github.com/melMass/comfy_mtb.git && \
    cd comfy_mtb && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..

# Para ImageResizeKJv2 (vem de KJNodes, que é rgthree-related, mas clone separado se necessário)
# Se já tiver em rgthree, pode pular; senão:
RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    cd ComfyUI-KJNodes && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..

RUN git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git && \
    cd ComfyUI-Frame-Interpolation && \
    python install.py


# Baixa models com URLs corretas (resolve/main + ?download=true para forçar binário)
RUN mkdir -p /comfyui/models/checkpoints && \
    wget -c -O /comfyui/models/checkpoints/wan2.2-i2v-rapid-aio-v10-nsfw.safetensors \
    "https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/v10/wan2.2-i2v-rapid-aio-v10-nsfw.safetensors?download=true"

RUN mkdir -p /comfyui/models/clip_vision && \
    wget -c -O /comfyui/models/clip_vision/CLIP-ViT-H-fp16.safetensors \
    "https://huggingface.co/Kijai/CLIPVisionModelWithProjection_fp16/resolve/main/CLIP-ViT-H-fp16.safetensors?download=true"

RUN mkdir -p /comfyui/models/upscale_models && \
    wget -c -O /comfyui/models/upscale_models/rife49.pth \
    "https://huggingface.co/hfmaster/models-moved/resolve/main/rife/rife49.pth?download=true"

# Opcional: Se quiser usar comfy-cli para models extras (mas wget é mais confiável aqui)
# RUN comfy model download --url "https://huggingface.co/Phr00t/.../resolve/main/..." --relative-path models/checkpoints --filename wan2.2-i2v-rapid-aio-v10-nsfw.safetensors

# Refresh cache do ComfyUI (boa prática após installs)  # ou apenas restart no handler

# O handler da base já cuida do resto (não precisa CMD extra)
RUN echo "================ DEBUG 1: CUSTOM NODES TREE ================" && \
    ls -R /comfyui/custom_nodes && \
    echo "============================================================="

RUN echo "================ DEBUG 2: FIND CKPTS / RIFE ================" && \
    find /comfyui -type d -iname "*ckpt*" && \
    find /comfyui -type d -iname "*rife*" && \
    echo "============================================================="

RUN echo "================ DEBUG 3: FIND RIFE49 FILE ==================" && \
    find /comfyui -name "rife49.pth" -exec ls -lh {} \; && \
    echo "============================================================="

RUN echo "================ DEBUG 4: GREP MODEL PATH ===================" && \
    grep -R "folder_paths" -n /comfyui/custom_nodes || true && \
    grep -R "get_ckpt" -n /comfyui/custom_nodes || true && \
    grep -R "rife" -n /comfyui/custom_nodes/comfyui-frame-interpolation || true && \
    echo "============================================================="