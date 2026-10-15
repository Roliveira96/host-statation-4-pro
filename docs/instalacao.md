# Instalação do zero

Passo a passo para montar o ambiente numa máquina nova. Os passos ainda não
implementados estão marcados como *(a fazer)*.

## 1. Preparar a máquina

```bash
sudo apt install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER      # só o administrador, nunca estagiários
docker info | grep -i "cgroup"     # precisa ser: systemd e versão 2
```

## 2. Clonar este repositório

```bash
git clone <url-do-repositorio> ~/estagio
cd ~/estagio
```

## 3. Criar os estagiários

```bash
sudo scripts/novo-estagiario.sh estagiario1
sudo scripts/novo-estagiario.sh estagiario2
```

Parâmetros opcionais: tamanho do disco e limite de RAM.

```bash
sudo scripts/novo-estagiario.sh fulano 20G 2G
```

O script pode rodar de novo com segurança: só cria o que falta e atualiza o
limite de RAM.

Conferir:

```bash
df -h /home/estagiario1                                # ~50G
systemctl show user-$(id -u estagiario1).slice -p MemoryMax
```

## 4. Domínio na Cloudflare

1. Criar conta na Cloudflare (plano Free) e adicionar o domínio.
2. No registrador (Registro.br / Hostinger), trocar os nameservers pelos dois
   que a Cloudflare indicar.
3. Se o domínio tiver e-mail, conferir que os registros MX e TXT (SPF) foram
   importados.
4. Esperar o status ficar **Active**.

## 5. Cloudflare Tunnel *(a fazer)*

## 6. Serviços web: nginx, PHP, MariaDB, phpMyAdmin, File Browser *(a fazer)*

## 7. SSH e segurança *(a fazer)*
