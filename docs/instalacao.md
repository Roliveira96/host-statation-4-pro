# Instalação do zero

Passo a passo para montar o ambiente numa máquina nova. Os passos ainda não
implementados estão marcados como *(a fazer)*.

## 1. Preparar a máquina

```bash
sudo apt install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER      # só o administrador, nunca estagiários
docker info | grep -i "cgroup"     # precisa ser: systemd e versão 2
```

## 2. Clonar e configurar

```bash
git clone https://github.com/Roliveira96/host-statation-4-pro.git ~/estagio
cd ~/estagio
cp .env.example .env
nano .env        # DOMINIO e MARIADB_ROOT_PASSWORD (openssl rand -base64 24)
chmod 600 .env
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
limite de RAM. No fim ele chama `scripts/ativar-estagiario.sh`, que:

- gera `estagiarios/<nome>.yaml` a partir do modelo (container web + painel);
- cria o login do painel e o usuário do banco, com senhas aleatórias salvas em
  `credenciais/<nome>.txt`;
- sobe os containers (na primeira vez também sobe nginx, MariaDB e phpMyAdmin).

Cada estagiário recebe na home:

- `public_html/`: o site, em `<nome>.<dominio>`; subpastas viram
  `<nome>.<dominio>/projeto`
- `privado/`: arquivos que nunca aparecem no site

Conferir:

```bash
df -h /home/estagiario1                                # ~50G
systemctl show user-$(id -u estagiario1).slice -p MemoryMax
scripts/estagio ps                                     # containers rodando
curl -H "Host: estagiario1.$DOMINIO" http://127.0.0.1/ # site, antes do túnel
```

## 4. Domínio na Cloudflare

1. Criar conta na Cloudflare (plano Free) e adicionar o domínio.
2. No registrador (Registro.br / Hostinger), trocar os nameservers pelos dois
   que a Cloudflare indicar.
3. Se o domínio tiver e-mail, conferir que os registros MX e TXT (SPF) foram
   importados.
4. Esperar o status ficar **Active**.

## 5. Cloudflare Tunnel *(a fazer)*

## 6. Serviços web

Já sobem com o passo 3. Resumo do que roda:

| Container | O que é | Porta no servidor |
|---|---|---|
| `estagio-proxy` | nginx, roteia por subdomínio | 80 |
| `estagio-mariadb` | MariaDB 11.4 | 3306 |
| `estagio-phpmyadmin` | phpMyAdmin, via `db.<dominio>` | (só pelo nginx) |
| `web-<nome>` | Apache + PHP 8.3, roda como o estagiário | (só pelo nginx) |
| `painel-<nome>` | File Browser, via `painel.<dominio>/<nome>/` | (só pelo nginx) |

No PHP, o banco é `host=mariadb`, porta 3306, com o usuário e a senha do
estagiário. Ele só cria e acessa bancos com o prefixo `<nome>_`.

Comandos do dia a dia:

```bash
scripts/estagio ps                      # o que está rodando
scripts/estagio logs -f web-estagiario1 # erros do PHP/Apache do estagiário
scripts/estagio restart proxy           # depois de mexer no proxy/
```

## 7. SSH e segurança *(a fazer)*
