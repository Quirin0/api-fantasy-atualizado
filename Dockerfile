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
# Symlink só o modelo do storage (assume que no storage tem ckpts/rife/rife49.pth)
RUN mkdir -p /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife && \
    ln -sfn /runpod-volume/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth \
            /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth || echo "Symlink do rife ok ou já existe"

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


# Instala dependências extras (mova para cima para melhor cache)
RUN pip install --no-cache-dir boto3 requests websockets

# Copia handler custom
COPY handler.py /handler.py

# Cria o startup script (com polling de 90s para cold starts mais longos)
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Iniciando ComfyUI em background..."\n\
python /comfyui/main.py --listen 127.0.0.1 --port 8188 --enable-cors-header "*" &\n\
\n\
echo "Aguardando ComfyUI iniciar (até 90s)..."\n\
for i in {1..90}; do\n\
  if curl -s -f http://127.0.0.1:8188/ > /dev/null; then\n\
    echo "ComfyUI pronto! (porta 8188 respondendo)"\n\
    break\n\
  fi\n\
  sleep 1\n\
done\n\
\n\
if ! curl -s -f http://127.0.0.1:8188/ > /dev/null; then\n\
  echo "AVISO: ComfyUI não iniciou em 90s - verifique logs para erros no boot"\n\
fi\n\
\n\
exec python -u /handler.py\n' > /start.sh && \
    chmod +x /start.sh

# CMD final: roda o startup script
CMD ["/start.sh"]

# Ajuste o download do rife49.pth para o caminho correto (ckpts/rife)
RUN mkdir -p /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife && \
    wget -c -O /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth \
    "https://huggingface.co/hfmaster/models-moved/resolve/main/rife/rife49.pth?download=true" || \
    wget -c -O /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth \
    "https://huggingface.co/Isi99999/Frame_Interpolation_Models/resolve/main/rife49.pth?download=true"

# Seus debugs (remova os ls /runpod-volume se incomodar, pois falham no build)
RUN echo "================ DEBUG: VERIFICAÇÃO DO RIFE49.PTH (agora em ckpts) ================" && \
    ls -la /comfyui/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife || echo "Pasta ckpts/rife não encontrada!" && \
    find /comfyui/custom_nodes -name "rife49.pth" -exec ls -lh {} \; || echo "rife49.pth NÃO FOI BAIXADO!" && \
    echo "================ DEBUG: CUSTOM NODES ================" && \
    ls -la /comfyui/custom_nodes && \
    echo "================================================================"
