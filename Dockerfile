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

# Debug final (veja nos Build Logs)
RUN echo "================ DEBUG: CUSTOM NODES INSTALADOS ================" && \
    ls -la /comfyui/custom_nodes && \
    echo "================ DEBUG: MODELS (se baixados) ==================" && \
    ls -la /comfyui/models/checkpoints 2>/dev/null || echo "No checkpoints" && \
    ls -la /comfyui/models/clip_vision 2>/dev/null || echo "No clip_vision" && \
    ls -la /comfyui/models/upscale_models 2>/dev/null || echo "No upscale_models" && \
    echo "================================================================"