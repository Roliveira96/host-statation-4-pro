#!/usr/bin/env bash
# Cadastra a chave pública SSH de um estagiário (as contas não têm senha).
# Roda sem sudo: grava como o próprio estagiário, via container.
# Uso: scripts/chave-ssh.sh <nome> <arquivo.pub>
#      scripts/chave-ssh.sh <nome> "ssh-ed25519 AAAA... comentario"
set -euo pipefail

NOME="${1:?uso: $0 <nome> <arquivo.pub | \"chave\">}"
CHAVE="${2:?uso: $0 <nome> <arquivo.pub | \"chave\">}"
[[ -f $CHAVE ]] && CHAVE=$(<"$CHAVE")
[[ $CHAVE =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+)\ [A-Za-z0-9+/=]+ ]] \
    || { echo "isso não parece uma chave pública SSH (.pub)"; exit 1; }
id "$NOME" &>/dev/null || { echo "estagiário $NOME não existe"; exit 1; }

docker run --rm --user "$(id -u "$NOME"):$(id -g "$NOME")" -v "/home/$NOME:/home/$NOME" \
    -e NOME="$NOME" -e CHAVE="$CHAVE" \
    --entrypoint sh filebrowser/filebrowser:v2.31.2 -c '
    set -e
    cd "/home/$NOME"
    mkdir -p .ssh && chmod 700 .ssh
    touch .ssh/authorized_keys && chmod 600 .ssh/authorized_keys
    if grep -qxF "$CHAVE" .ssh/authorized_keys; then
        echo "   chave já estava cadastrada"
    else
        echo "$CHAVE" >> .ssh/authorized_keys
        echo "   chave cadastrada para $NOME"
    fi'
