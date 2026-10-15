# Instalação do zero

> ## 🛑 Estagiário, pare aqui!
>
> Este guia é para quem **monta o servidor**, não para quem usa. Você **não**
> precisa fazer nada disto para usar o seu espaço no PS4. Tudo o que você
> precisa está no [README](../README.md): painel, site, banco e
> [acesso por SSH](../README.md#acesso-por-ssh).
>
> Rodar estes comandos no seu SSH do servidor não vai funcionar (você não tem
> `sudo`, e ainda bem). No máximo vai gerar um e-mail do Ricardo com o assunto
> "o que você estava tentando fazer?".
>
> **Exceção honrosa:** você tem um PS4 (ou qualquer PC com Linux) parado em
> casa e quer montar **a sua própria** versão para testar, estudar ou impressionar
> a família no almoço de domingo? Aí este guia é seu, pode seguir. Só lembre:
>
> - O console vai virar servidor. Seus saves vão sentir sua falta.
> - A ventoinha vai decolar. Avise os vizinhos.
> - Na sua máquina, **você** é o Ricardo. Os bugs agora são seus. Bem-vindo
>   ao outro lado.
>
> Pronto para assumir as consequências? Pressione ✕ para continuar.

Passo a passo para montar o ambiente numa máquina nova. Os passos ainda não
implementados estão marcados como *(a fazer)*.

Para replicar em outra máquina, troque `rmo.dev.br` pelo seu domínio e use
o seu próprio túnel da Cloudflare: cada instalação tem o seu `.env`, as suas
senhas e os seus estagiários (nem que sejam você mesmo com nomes diferentes).

## 1. Preparar a máquina

```bash
sudo apt install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER      # só o administrador, nunca estagiários
docker info | grep -i "cgroup"     # precisa ser: systemd e versão 2
```

Depois de clonar o repositório (passo 2), ajuste o sistema uma vez:

```bash
sudo scripts/configurar-sistema.sh
```

Ele liga a swap comprimida na RAM (zram, metade da RAM, zstd) e ajusta
`swappiness`/`page-cluster` para ela. Swap em disco foi evitada de propósito:
o disco do PS4 é lento e o sistema roda dentro de um arquivo `.img`, onde swap
pode travar justamente quando falta memória. Os estagiários continuam sem swap
(`MemorySwapMax=0`): a zram é reserva do sistema e dos serviços.

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

## 5. Cloudflare Tunnel

O túnel é gerenciado pelo painel da Cloudflare; aqui só roda o conector
(`estagio-cloudflared`, no `compose.yaml`).

1. No painel da Cloudflare: **Networks > Tunnels > Create a tunnel**, tipo
   **Cloudflared**, nome `ps4`. (O menu muda de nome às vezes; procure
   "Tunnels".)
2. Na tela de instalação, escolha Docker e copie o token (o texto depois de
   `--token`, começa com `eyJ`) para o `.env`:
   ```
   CLOUDFLARE_TUNNEL_TOKEN=eyJ...
   ```
3. Suba o conector e confira que ele registrou conexões:
   ```bash
   scripts/estagio up -d cloudflared
   docker logs estagio-cloudflared 2>&1 | grep Registered
   ```
   O erro sobre `cert.pem` no log é normal nesse modo.
4. No túnel, em **Routes > Add route > Published application**, crie:

   | Subdomain | Domain | Path | Service URL |
   |---|---|---|---|
   | `*` | seu domínio | (vazio) | `http://estagio-proxy:80` |

   O DNS (`CNAME *`) é criado automaticamente.

   O coringa só pega subdomínios que não têm registro próprio. Assim o domínio
   principal e o `www` podem continuar apontando para outro lugar (no nosso
   caso, o site pessoal na Hostinger), e o e-mail (MX) não é afetado. Se
   quiser que o domínio principal também caia aqui, crie uma rota com
   Subdomain vazio e apague o registro A antigo dele.

   Use `http://estagio-proxy:80`, não `localhost`: o conector roda num
   container, e `estagio-proxy` é o nginx na rede Docker.

## 6. Serviços web

Já sobem com o passo 3. Resumo do que roda:

| Container | O que é | Porta no servidor |
|---|---|---|
| `estagio-proxy` | nginx, roteia por subdomínio | 80 |
| `estagio-mariadb` | MariaDB 11.4 | 3306 |
| `estagio-phpmyadmin` | phpMyAdmin, via `db.<dominio>` | (só pelo nginx) |
| `web-<nome>` | Apache + PHP 8.3, roda como o estagiário | (só pelo nginx) |
| `painel-<nome>` | File Browser, via `painel.<dominio>/<nome>/` | (só pelo nginx) |

O painel tem uma tela de login própria em `painel.<dominio>` (usuário e senha
juntos). Ela faz o login no File Browser do estagiário e já abre a pasta dele;
a tela de login do File Browser redireciona para ela.

Ao mudar o `proxy/html/estilo.css`, aumente o `?v=` no link das páginas: a
Cloudflare guarda CSS em cache por horas.

No PHP, o banco é `host=mariadb`, porta 3306, com o usuário e a senha do
estagiário. Ele só cria e acessa bancos com o prefixo `<nome>_`.

Comandos do dia a dia:

```bash
scripts/estagio ps                      # o que está rodando
scripts/estagio logs -f web-estagiario1 # erros do PHP/Apache do estagiário
scripts/estagio restart proxy           # depois de mexer no proxy/
```

## 7. SSH pelo túnel

O SSH do servidor continua na porta 22 e não fica exposto: quem está fora entra
por `ssh.<dominio>`, pelo mesmo túnel.

1. No túnel, em **Routes > Add route > Published application**:

   | Subdomain | Domain | Path | Service URL |
   |---|---|---|---|
   | `ssh` | seu domínio | (vazio) | `ssh://host.docker.internal:22` |

2. **Arraste essa rota para cima da `*.<dominio>`.** As rotas são lidas de
   cima para baixo, e o coringa pegaria o `ssh` primeiro.
3. O `compose.yaml` já dá ao conector o nome `host.docker.internal`
   (`extra_hosts`), que é o próprio servidor visto de dentro do container.
4. Cadastre a chave pública de cada estagiário:
   ```bash
   scripts/chave-ssh.sh estagiario1 id_ed25519.pub
   ```

Como conectar (Windows, macOS, Linux, VS Code): veja "Acesso por SSH" no
README.

*(a fazer: SSH dos estagiários num container isolado; login por e-mail com
Cloudflare Access)*
