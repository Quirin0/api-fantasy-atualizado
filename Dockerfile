# Use base recente (atualize se possível; 5.5.1 pode ter bugs – teste latest se disponível)
FROM runpod/worker-comfyui:5.5.1-base

# Atualiza e instala ferramentas básicas
RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget curl && \
    rm -rf /var/lib/apt/lists/*

# WORKDIR para custom_nodes
WORKDIR /comfyui/custom_nodes

# Clones dos nodes (mantém o Frame-Interpolation com case correto)
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

# Symlink do rife49.pth do storage para o caminho correto (ckpts/rife – oficial do repo)
RUN mkdir -p /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife && \
    ln -sfn /runpod-volume/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth \
            /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth || echo "Symlink rife ok ou já existe"

# Instala dependências extras (boto3 pro seu handler)
RUN pip install --no-cache-dir boto3 requests websockets

# Copia seu handler custom
COPY handler.py /handler.py

# Força symlink do handler se a base image usar /rp-start (fallback seguro)
RUN ln -sf /handler.py /rp-start/handler.py 2>/dev/null || true

# NÃO adicione CMD novo – use o da base image (/start.sh que inicia ComfyUI + handler)
# Se precisar override, teste: CMD ["/start.sh"]

# Debugs (úteis nos build logs)
RUN echo "================ DEBUG: VERIFICAÇÃO RIFE49.PTH ================" && \
    ls -la /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife || echo "ckpts/rife não encontrada!" && \
    find /comfyui/custom_nodes -name "*rife49.pth*" -exec ls -lh {} \; || echo "rife49.pth não encontrado!" && \
    echo "================ DEBUG: CUSTOM NODES ================" && \
    ls -la /comfyui/custom_nodes && \
    echo "================ DEBUG: PATHS COMFYUI ================" && \
    ls -la /comfyui || echo "/comfyui não encontrada!" && \
    echo "================================================================"
