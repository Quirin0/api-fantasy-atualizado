# Use base recente (atualize se possível; 5.5.1 pode ter bugs)
FROM runpod/worker-comfyui:5.5.1-base

# Atualiza e instala ferramentas básicas
RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget curl && \
    rm -rf /var/lib/apt/lists/*

# WORKDIR para custom_nodes
WORKDIR /comfyui/custom_nodes

# rgthree-comfy (tem requirements.txt)
RUN git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    cd rgthree-comfy && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..

# VideoHelperSuite (tem requirements.txt)
RUN git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    cd ComfyUI-VideoHelperSuite && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..

# WanVideoWrapper (tem requirements.txt)
RUN git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    cd ComfyUI-WanVideoWrapper && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..

# comfy_mtb (tem requirements.txt)
RUN git clone --depth 1 https://github.com/melMass/comfy_mtb.git && \
    cd comfy_mtb && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..

# KJNodes (para ImageResizeKJv2)
RUN git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git && \
    cd ComfyUI-KJNodes && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..

# mxToolkit (SEM requirements.txt – só clone)
RUN git clone --depth 1 https://github.com/Smirnov75/ComfyUI-mxToolkit.git

# Frame-Interpolation (usa install.py – sem requirements.txt)
RUN git clone --depth 1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git && \
    cd ComfyUI-Frame-Interpolation && \
    python install.py && \
    cd ..

# Se você usa Network Volume com models já baixados → NÃO BAIXE NADA AQUI
# Remova os wget abaixo se o volume já tem os arquivos
# Caso contrário, mantenha para build inicial

# WAN checkpoint (grande – só se necessário)
# RUN mkdir -p /comfyui/models/checkpoints && \
#     wget -c -O /comfyui/models/checkpoints/wan2.2-i2v-rapid-aio-v10-nsfw.safetensors \
#     "https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/v10/wan2.2-i2v-rapid-aio-v10-nsfw.safetensors?download=true"

# CLIP Vision
# RUN mkdir -p /comfyui/models/clip_vision && \
#     wget -c -O /comfyui/models/clip_vision/CLIP-ViT-H-fp16.safetensors \
#     "https://huggingface.co/Kijai/CLIPVisionModelWithProjection_fp16/resolve/main/CLIP-ViT-H-fp16.safetensors?download=true"

# RIFE para interpolation
# RUN mkdir -p /comfyui/models/upscale_models && \
#     wget -c -O /comfyui/models/upscale_models/rife49.pth \
#     "https://huggingface.co/hfmaster/models-moved/resolve/main/rife/rife49.pth?download=true"

# Cria pastas padrão (se não existirem)
RUN mkdir -p /comfyui/models /comfyui/custom_nodes

# Symlink SOMENTE para models (já que você tem tudo no volume)
RUN ln -sfn /runpod-volume/models /comfyui/models && \
    # Opcionais para subpastas comuns dentro de models
    ln -sfn /runpod-volume/models/checkpoints /comfyui/models/checkpoints 2>/dev/null || true && \
    ln -sfn /runpod-volume/models/clip_vision /comfyui/models/clip_vision 2>/dev/null || true && \
    ln -sfn /runpod-volume/models/upscale_models /comfyui/models/upscale_models 2>/dev/null || true && \
    ln -sfn /runpod-volume/models/loras /comfyui/models/loras 2>/dev/null || true

# Debug (mantenha para verificar)
RUN echo "================ DEBUG: VERIFICAÇÃO DO VOLUME E SYMLINKS ================" && \
    ls -la /runpod-volume || echo "ERRO: /runpod-volume NÃO MONTADO ou vazio!" && \
    ls -la /runpod-volume/models || echo "ERRO: /runpod-volume/models não existe!" && \
    ls -la /comfyui/models || echo "ERRO: symlink para models falhou" && \
    find /runpod-volume/models -name "*wan2.2*.safetensors" || echo "WAN checkpoint não encontrado no volume" && \
    find /runpod-volume/models -name "*CLIP-ViT-H*.safetensors" || echo "CLIP Vision não encontrado" && \
    find /runpod-volume/models -name "rife49.pth" || echo "RIFE não encontrado" && \
    echo "================ DEBUG: CUSTOM NODES (clonados no build) ================" && \
    ls -la /comfyui/custom_nodes && \
    echo "================================================================"