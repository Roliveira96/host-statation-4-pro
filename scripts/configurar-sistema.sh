#!/usr/bin/env bash
# Ajustes do sistema do servidor (rodar uma vez, com sudo):
#   - swap comprimida na RAM (zram), metade da RAM, zstd
#   - swappiness e page-cluster adequados para zram
# Os estagiários continuam sem swap (MemorySwapMax=0 na slice deles):
# a zram é reserva para o sistema e os serviços.
# Pode rodar de novo com segurança.
# Uso: sudo scripts/configurar-sistema.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "rode com sudo"; exit 1; }
cd "$(dirname "$(readlink -f "$0")")/.."

echo "== swap em zram"
apt-get install -y -qq systemd-zram-generator >/dev/null
install -m 644 config/sistema/zram-generator.conf /etc/systemd/zram-generator.conf
systemctl daemon-reload
systemctl restart systemd-zram-setup@zram0.service

echo "== ajustes de memória"
install -m 644 config/sistema/99-swap-zram.conf /etc/sysctl.d/99-swap-zram.conf
sysctl -q --system

swapon --show
echo "   swappiness: $(cat /proc/sys/vm/swappiness)  page-cluster: $(cat /proc/sys/vm/page-cluster)"
