#!/usr/bin/env bash
# Liga os serviços de um estagiário já criado com novo-estagiario.sh:
#   - container web (Apache + PHP 8.3) e painel (File Browser), rodando como ele
#   - usuário no MariaDB com acesso só aos bancos <nome>_*
#   - login do painel de arquivos
# As senhas geradas ficam em credenciais/<nome>.txt (fora do Git).
# Roda sem sudo (precisa estar no grupo docker). Pode rodar de novo com segurança.
# Uso: scripts/ativar-estagiario.sh <nome>
set -euo pipefail
cd "$(dirname "$0")/.."

NOME="${1:?uso: $0 <nome>}"
id "$NOME" &>/dev/null || { echo "estagiário não existe. Rode antes: sudo scripts/novo-estagiario.sh $NOME"; exit 1; }
[[ -f .env ]] || { echo "falta o .env (copie de .env.example e preencha)"; exit 1; }
set -a; . ./.env; set +a

USER_UID=$(id -u "$NOME")
USER_GID=$(id -g "$NOME")
echo "== ativando $NOME (uid $USER_UID)"

# 1. Containers do estagiário a partir do modelo
sed -e "s/__NOME__/$NOME/g" -e "s/__UID__/$USER_UID/g" -e "s/__GID__/$USER_GID/g" \
    estagiarios/_modelo.yaml > "estagiarios/$NOME.yaml"

# 2. Senhas (geradas uma vez só)
CRED="credenciais/$NOME.txt"
gerar_senha() { openssl rand -base64 24 | tr -d '/+=' | cut -c1-16; }
(umask 077; mkdir -p credenciais)
if [[ ! -f $CRED ]]; then
    (umask 077; cat > "$CRED" <<EOF
# PlayStagiário 4 · credenciais de $NOME (NÃO vai para o Git)
SITE=https://$NOME.$DOMINIO
PAINEL_URL=https://painel.$DOMINIO/$NOME/
PAINEL_USUARIO=$NOME
PAINEL_SENHA=$(gerar_senha)
BANCO_PHPMYADMIN=https://db.$DOMINIO
BANCO_HOST_NO_PHP=mariadb
BANCO_PORTA=3306
BANCO_USUARIO=$NOME
BANCO_SENHA=$(gerar_senha)
BANCO_PREFIXO=${NOME}_
EOF
    )
fi
. "$CRED"

# 3. Pastas e painel de arquivos
#    public_html = site; privado = nunca vai para o site
#    O banco do File Browser fica num volume próprio (fora da home), criado com
#    o usuário antes do primeiro start: sem isso ele nasceria com admin/admin.
docker run --rm --user "$USER_UID:$USER_GID" -v "/home/$NOME:/home/$NOME" \
    --entrypoint sh filebrowser/filebrowser:v2.31.2 \
    -c "mkdir -p /home/$NOME/public_html /home/$NOME/privado; rm -rf /home/$NOME/.painel"
docker volume create "estagio-painel-$NOME" >/dev/null
docker run --rm -v "estagio-painel-$NOME:/dados" \
    -e NOME="$NOME" -e SENHA="$PAINEL_SENHA" -e DONO="$USER_UID:$USER_GID" \
    --entrypoint sh filebrowser/filebrowser:v2.31.2 -c '
    set -e
    DB=/dados/filebrowser.db
    if [ ! -f "$DB" ]; then
        /filebrowser -d "$DB" config init --root "/home/$NOME" --baseurl "/$NOME" \
            --branding.name "PlayStagiário 4 · $NOME" --auth.method json \
            --locale pt-br --perm.execute=false --commands "" >/dev/null 2>&1
    fi
    if ! /filebrowser -d "$DB" users find "$NOME" >/dev/null 2>&1; then
        /filebrowser -d "$DB" users add "$NOME" "$SENHA" \
            --perm.admin=false --perm.execute=false --locale pt-br >/dev/null 2>&1
        echo "   painel: login $NOME criado"
    fi
    chown -R "$DONO" /dados'

# 4. Usuário do banco: só enxerga bancos que começam com <nome>_
scripts/estagio up -d --wait mariadb >/dev/null
docker exec -i -e MYSQL_PWD="$MARIADB_ROOT_PASSWORD" estagio-mariadb mariadb -uroot <<SQL
CREATE USER IF NOT EXISTS '$NOME'@'%' IDENTIFIED BY '$BANCO_SENHA';
ALTER USER '$NOME'@'%' IDENTIFIED BY '$BANCO_SENHA' WITH MAX_USER_CONNECTIONS 15;
GRANT ALL PRIVILEGES ON \`${NOME}\\_%\`.* TO '$NOME'@'%';
FLUSH PRIVILEGES;
SQL
echo "   banco: usuário $NOME com acesso a ${NOME}_*"

# 5. Sobe tudo
scripts/estagio up -d --build "web-$NOME" "painel-$NOME" proxy phpmyadmin
echo "   pronto. Credenciais em $CRED"
