#!/usr/bin/env bash
# Publica um projeto Go do administrador (não de estagiário) num subdomínio
# ou num domínio próprio, sem Dockerfile:
#   - apps/<nome>.yaml: container app-<nome> com a imagem oficial do Go, que
#     compila a pasta do projeto a cada (re)início e roda o binário
#   - proxy/apps/<nome>.conf: rota do nginx para os endereços informados
# Endereço sem ponto vira <endereço>.<DOMINIO>; com ponto é um domínio
# completo (que precisa de rota própria no túnel: veja docs/apps-go.md).
# Roda sem sudo (precisa estar no grupo docker). Pode rodar de novo com
# segurança: refaz o container e a rota com os dados novos.
# Uso: scripts/novo-app.sh <nome> <pasta-do-projeto> <endereço> [endereço...]
#      PORTA=8080 MEMORIA=512m scripts/novo-app.sh ...   (padrões)
set -euo pipefail
cd "$(dirname "$0")/.."

uso="uso: $0 <nome> <pasta-do-projeto> <endereço> [endereço...]"
NOME="${1:?$uso}"
PASTA="${2:?$uso}"
shift 2
[[ $# -ge 1 ]] || { echo "$uso"; exit 1; }
PORTA="${PORTA:-8080}"
MEMORIA="${MEMORIA:-512m}"

[[ $EUID -ne 0 ]] || { echo "rode sem sudo, como o seu usuário (grupo docker)"; exit 1; }
[[ -f .env ]] || { echo "falta o .env (copie de .env.example e preencha)"; exit 1; }
set -a; . ./.env; set +a

[[ $NOME =~ ^[a-z][a-z0-9-]{0,30}$ ]] || { echo "nome inválido: use minúsculas, números e hífen"; exit 1; }
[[ $PORTA =~ ^[0-9]+$ ]] || { echo "PORTA inválida: $PORTA"; exit 1; }
PASTA="$(readlink -f "$PASTA")"
[[ -f $PASTA/go.mod ]] || { echo "não achei $PASTA/go.mod: a pasta precisa ser um projeto Go"; exit 1; }

# Endereços: subdomínio do DOMINIO ou domínio completo
RESERVADOS=" www painel db nas ssh mail "
HOSTS=()
for e in "$@"; do
    e="${e,,}"
    [[ $e == *.* ]] || e="$e.$DOMINIO"
    [[ $e =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]] || { echo "endereço inválido: $e"; exit 1; }
    if [[ $e == *".$DOMINIO" ]]; then
        sub="${e%."$DOMINIO"}"
        [[ $sub != *.* ]] || { echo "$e: o certificado grátis da Cloudflare só cobre um nível; use hífen (ex.: api-loja.$DOMINIO)"; exit 1; }
        [[ $RESERVADOS != *" $sub "* ]] || { echo "$e: '$sub' é reservado"; exit 1; }
        [[ ! -f estagiarios/$sub.yaml ]] || { echo "$e: '$sub' é o site de um estagiário"; exit 1; }
    elif [[ $e == "$DOMINIO" ]]; then
        echo "$DOMINIO aponta para o site principal, não para o PS4"; exit 1
    fi
    for f in proxy/apps/*.conf; do
        [[ -f $f && $f != "proxy/apps/$NOME.conf" ]] || continue
        ! grep -qw -- "$e" "$f" || { echo "$e já é usado por $(basename "$f" .conf)"; exit 1; }
    done
    HOSTS+=("$e")
done

CACHE="$HOME/.cache/estagio-go"
mkdir -p "$CACHE"
echo "== app $NOME: $PASTA -> ${HOSTS[*]} (porta $PORTA, $MEMORIA)"

# 1. Container a partir do modelo
sed -e "s|__NOME__|$NOME|g" -e "s|__PASTA__|$PASTA|g" -e "s|__PORTA__|$PORTA|g" \
    -e "s|__MEMORIA__|$MEMORIA|g" -e "s|__UID__|$(id -u)|g" -e "s|__GID__|$(id -g)|g" \
    -e "s|__CACHE__|$CACHE|g" apps/_modelo.yaml > "apps/$NOME.yaml"

# 2. Rota no nginx (o container é achado pelo DNS do Docker na hora da visita)
cat > "proxy/apps/$NOME.conf" <<EOF
# Gerado por scripts/novo-app.sh: app-$NOME ($PASTA)
server {
    listen 80;
    server_name ${HOSTS[*]};
    error_page 502 504 =503 /app-desligado.html;

    location / {
        set \$alvo app-$NOME;
        proxy_pass http://\$alvo:$PORTA;
    }
    location = /app-desligado.html {
        root /usr/share/nginx/html;
        internal;
    }
}
EOF

# 3. Sobe o app e recarrega o nginx
scripts/estagio up -d proxy "app-$NOME"
docker exec estagio-proxy nginx -t -q
docker exec estagio-proxy nginx -s reload

echo "== pronto. O primeiro build demora; acompanhe com: scripts/estagio logs -f app-$NOME"
for e in "${HOSTS[@]}"; do
    if [[ $e == *".$DOMINIO" ]]; then
        echo "   https://$e"
    else
        echo "   https://$e  (domínio próprio: crie a rota no túnel, veja docs/apps-go.md)"
    fi
done
