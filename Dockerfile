# Use base recente (atualize se possível; 5.5.1 pode ter bugs – teste latest se disponível)
FROM runpod/worker-comfyui:5.5.1-base

# Atualiza e instala ferramentas básicas
RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget curl && \
    rm -rf /var/lib/apt/lists/*

# WORKDIR para custom_nodes
WORKDIR /comfyui/custom_nodes

# Clones dos nodes (agrupados)
RUN git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    cd rgthree-comfy && pip install --no-cache-dir -r requirements.txt && cd .. && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    cd ComfyUI-VideoHelperSuite && pip install --no-cache-dir -r requirements.txt && cd .. && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    cd ComfyUI-WanVideoWrapper && pip install --no-cache-dir -r requirements.txt && cd .. && \
    git clone --depth 1 https://github.com/melMass/comfy_mtb.git && \
    cd comfy_mtb && pip install --no-cache-dir -r requirements.txt && cd .. && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git && \
    cd ComfyUI-KJNodes && pip install --no-cache-dir -r requirements.txt && cd .. && \
    git clone --depth 1 https://github.com/Smirnov75/ComfyUI-mxToolkit.git && \
    git clone --depth 1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git && \
    cd ComfyUI-Frame-Interpolation && python install.py && cd ..

# Symlink do rife49.pth do storage (caminho correto: ckpts/rife)
# mkdir -p garante a pasta existe no container antes do symlink
RUN mkdir -p /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife && \
    ln -sfn /runpod-volume/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth \
            /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth || echo "Symlink rife49.pth ok ou já existe"

# Instala dependências extras pro handler
RUN pip install --no-cache-dir boto3 requests websockets

# Copia handler custom
COPY handler.py /handler.py

# Fallback symlink para /rp-start (se a base image usar isso pro handler)
RUN ln -sf /handler.py /rp-start/handler.py 2>/dev/null || true

# Debugs nos build logs
RUN echo "================ DEBUG: VERIFICAÇÃO RIFE49.PTH ================" && \
    ls -la /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife 2>/dev/null || echo "ckpts/rife não encontrada (normal com symlink runtime)" && \
    find /comfyui/custom_nodes -name "*rife49.pth*" -exec ls -lh {} \; 2>/dev/null || echo "rife49.pth não encontrado no build" && \
    echo "================ DEBUG: CUSTOM NODES ================" && \
    ls -la /comfyui/custom_nodes && \
    echo "================ DEBUG: COMFYUI PATHS ================" && \
    ls -la /comfyui 2>/dev/null || echo "/comfyui não encontrada!" && \
    echo "================================================================"
