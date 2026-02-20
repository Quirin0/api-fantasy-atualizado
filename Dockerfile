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

# === BAIXA O RIFE49.PTH NA PASTA EXATA QUE O NODE ESPERA ===
# Cria a estrutura de pastas se não existir (por segurança)
RUN mkdir -p /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/vfi_models/rife && \
    wget -c -O /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/vfi_models/rife/rife49.pth \
    "https://huggingface.co/hfmaster/models-moved/resolve/main/rife/rife49.pth?download=true" || \
    wget -c -O /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/vfi_models/rife/rife49.pth \
    "https://huggingface.co/Isi99999/Frame_Interpolation_Models/resolve/main/rife49.pth?download=true"

# Cria pastas padrão do ComfyUI (se não existirem)
RUN mkdir -p /comfyui/models /comfyui/custom_nodes

# Symlink SOMENTE para models (já que você tem tudo no volume)
RUN ln -sfn /runpod-volume/models /comfyui/models && \
    ln -sfn /runpod-volume/models/checkpoints /comfyui/models/checkpoints 2>/dev/null || true && \
    ln -sfn /runpod-volume/models/clip_vision /comfyui/models/clip_vision 2>/dev/null || true && \
    ln -sfn /runpod-volume/models/upscale_models /comfyui/models/upscale_models 2>/dev/null || true && \
    ln -sfn /runpod-volume/models/loras /comfyui/models/loras 2>/dev/null || true

# Debug para confirmar no Build Logs
RUN echo "================ DEBUG: VERIFICAÇÃO DO RIFE49.PTH ================" && \
    ls -la /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/vfi_models/rife || echo "Pasta rife não encontrada!" && \
    find /comfyui/custom_nodes -name "rife49.pth" -exec ls -lh {} \; || echo "rife49.pth NÃO FOI BAIXADO!" && \
    echo "================ DEBUG: VOLUME E SYMLINKS ================" && \
    ls -la /runpod-volume || echo "ERRO: /runpod-volume NÃO MONTADO ou vazio!" && \
    ls -la /runpod-volume/models || echo "ERRO: /runpod-volume/models não existe!" && \
    ls -la /comfyui/models || echo "ERRO: symlink para models falhou" && \
    echo "================ DEBUG: CUSTOM NODES (clonados no build) ================" && \
    ls -la /comfyui/custom_nodes && \
    echo "================================================================"