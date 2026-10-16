#!/usr/bin/env bash
# Tira do ar um app criado com novo-app.sh: para e apaga o container, a rota
# do nginx e o apps/<nome>.yaml. O código do projeto não é tocado.
# Uso: scripts/remover-app.sh <nome>
set -euo pipefail
cd "$(dirname "$0")/.."

NOME="${1:?uso: $0 <nome>}"
[[ -f apps/$NOME.yaml ]] || { echo "app $NOME não existe (veja apps/)"; exit 1; }

scripts/estagio rm -sf "app-$NOME"
rm -f "apps/$NOME.yaml" "proxy/apps/$NOME.conf"
# o nginx pode ter acabado de ser recriado: espera ele subir antes do reload
for _ in {1..20}; do docker exec estagio-proxy test -s /run/nginx.pid 2>/dev/null && break; sleep 0.5; done
docker exec estagio-proxy nginx -t -q
docker exec estagio-proxy nginx -s reload
echo "== app $NOME removido. Se tinha domínio próprio, apague a rota no túnel."
