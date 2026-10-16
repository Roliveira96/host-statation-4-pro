#!/usr/bin/env bash
# Prepara o disco do NAS (rodar uma vez, com sudo).
#   - disco virtual próprio, montado em /srv/nas (padrão 100 GB, esparso)
#   - os dados do Cloudreve ficam em /srv/nas/dados
# Se o disco não montar no boot, /srv/nas/dados não existe e o container do NAS
# se recusa a subir (melhor do que gravar no disco do sistema sem perceber).
# Depois: scripts/nas.py iniciar (sem sudo).
# Uso: sudo scripts/configurar-nas.sh [tamanho]      ex.: sudo scripts/configurar-nas.sh 100G
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "rode com sudo"; exit 1; }

TAMANHO="${1:-100G}"
[[ $TAMANHO =~ ^[0-9]+[GT]$ ]] || { echo "tamanho inválido: use algo como 100G"; exit 1; }
IMG=/srv/estagio/discos/nas.img
PONTO=/srv/nas

echo "== disco do NAS ($TAMANHO)"
mkdir -p /srv/estagio/discos && chmod 700 /srv/estagio/discos
if [[ ! -f $IMG ]]; then
    truncate -s "$TAMANHO" "$IMG"          # esparso: só ocupa no HD o que for usado
    mkfs.ext4 -q -m 0 -L nas "$IMG"
fi
mkdir -p "$PONTO"
if ! grep -q " $PONTO " /etc/fstab; then
    echo "$IMG $PONTO ext4 loop,discard,nofail,defaults 0 2" >> /etc/fstab
    systemctl daemon-reload
fi
mountpoint -q "$PONTO" || mount "$PONTO"
rmdir "$PONTO/lost+found" 2>/dev/null || true

# Pasta dos dados: só existe dentro do disco montado
install -d -m 700 "$PONTO/dados"
df -h "$PONTO" | tail -1
