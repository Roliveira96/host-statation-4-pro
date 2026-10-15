#!/usr/bin/env bash
# Cria (ou completa) a conta de um estagiário no PS4.
#   - usuário Linux sem senha (login será por chave SSH / painel)
#   - home num disco virtual próprio de 50 GB (o kernel do PS4 não tem quota)
#   - limite de 3 GB de RAM somando sessões SSH + containers (user-UID.slice)
# Uso: sudo scripts/novo-estagiario.sh <nome> [tamanho_disco] [limite_ram]
# Pode rodar de novo com segurança: só cria o que estiver faltando.
set -euo pipefail

NOME="${1:?uso: $0 <nome> [disco, ex 50G] [ram, ex 3G]}"
DISCO="${2:-50G}"
RAM="${3:-3G}"
DIR_DISCOS=/srv/estagio/discos
IMG="$DIR_DISCOS/$NOME.img"
HOME_DIR="/home/$NOME"

[[ $EUID -eq 0 ]] || { echo "rode com sudo"; exit 1; }
[[ $NOME =~ ^[a-z][a-z0-9-]{1,30}$ ]] || { echo "nome inválido (use minúsculas, números e hífen)"; exit 1; }
case $NOME in www|painel|db|ssh|api|mail) echo "\"$NOME\" é reservado (vira subdomínio do sistema)"; exit 1;; esac

echo "== $NOME: disco $DISCO, RAM $RAM"

# 1. Disco virtual (arquivo esparso: só ocupa no HD o que for usado de fato)
mkdir -p "$DIR_DISCOS"
chmod 700 "$DIR_DISCOS"
if [[ ! -f $IMG ]]; then
    truncate -s "$DISCO" "$IMG"
    mkfs.ext4 -q -m 0 -L "$NOME" "$IMG"
    echo "   disco criado: $IMG"
fi

# 2. Montagem permanente em /home/<nome> (discard devolve espaço ao HD quando apagam arquivos)
mkdir -p "$HOME_DIR"
if ! grep -q " $HOME_DIR " /etc/fstab; then
    echo "$IMG $HOME_DIR ext4 loop,discard,nofail,defaults 0 2" >> /etc/fstab
    systemctl daemon-reload
fi
mountpoint -q "$HOME_DIR" || mount "$HOME_DIR"

# 3. Usuário (sem senha; shell bash)
if ! id "$NOME" &>/dev/null; then
    useradd --home-dir "$HOME_DIR" --no-create-home --shell /bin/bash --user-group "$NOME"
    passwd -l "$NOME" >/dev/null
fi
cp -rn /etc/skel/. "$HOME_DIR"/ 2>/dev/null || true
mkdir -p "$HOME_DIR/public_html" "$HOME_DIR/privado"   # privado: nunca vai para o site
[[ -f $HOME_DIR/public_html/index.html ]] || cat > "$HOME_DIR/public_html/index.html" <<EOF
<!doctype html><meta charset="utf-8"><title>$NOME</title>
<h1>Olá, $NOME!</h1><p>Seu espaço está pronto. Suba seus projetos em <code>public_html</code>.</p>
EOF
rm -rf "$HOME_DIR/lost+found"
chown -R "$NOME:$NOME" "$HOME_DIR"
chmod 750 "$HOME_DIR"     # outros estagiários não entram

# 4. Limite de RAM: um teto só para tudo do estagiário.
#    Sessões SSH já caem em user-UID.slice; os containers dele vão usar
#    cgroup_parent: user-UID.slice, então somam no mesmo limite.
USER_UID=$(id -u "$NOME")
mkdir -p "/etc/systemd/system/user-$USER_UID.slice.d"
cat > "/etc/systemd/system/user-$USER_UID.slice.d/limite-estagio.conf" <<EOF
[Slice]
MemoryMax=$RAM
MemorySwapMax=0
EOF
systemctl daemon-reload

echo "   ok: uid $USER_UID, home $HOME_DIR ($(df -h --output=size "$HOME_DIR" | tail -1 | tr -d ' '))"

# 5. Liga os serviços (containers, painel, banco) como o administrador,
#    que é quem está no grupo docker
if [[ -n ${SUDO_USER:-} ]] && command -v docker >/dev/null; then
    sudo -u "$SUDO_USER" "$(dirname "$(readlink -f "$0")")/ativar-estagiario.sh" "$NOME"
else
    echo "   agora rode, sem sudo: scripts/ativar-estagiario.sh $NOME"
fi
