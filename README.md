# 🎮 PlayStagiário 4

> *"Pra que AWS se eu tenho um PS4 juntando poeira?"*

Infraestrutura de hospedagem para estagiários rodando num **PlayStation 4
velho**, com Linux, ligado na rede de casa e sem IP fixo. Cada estagiário
ganha seu cantinho estilo Hostinger: site próprio, banco de dados, painel de
arquivos e um console que já rodou God of War segurando o código PHP dele.

Ele já salvou Kratos, Aloy e o Spider-Man. Agora tem a missão mais difícil
da carreira: hospedar o primeiro `index.php` do estagiário. Aquele com
`<?php echo "teste"; ?>` e três `var_dump` esquecidos.

> 🐧 **Como o Linux foi parar no PS4?** Isso está no projeto irmão
> [**ubuntu-server-on-ps4**](https://github.com/Roliveira96/ubuntu-server-on-ps4): jailbreak, kernel, Ubuntu 26.04 numa
> imagem dentro do HD (sem apagar os jogos) e a pós-instalação (Wi-Fi, IP
> fixo, GPU, Docker). Este repositório começa onde aquele termina.

> ⚠️ Nenhum console foi maltratado na produção deste projeto. Ele só foi
> promovido de "centro de entretenimento" para "infraestrutura crítica" sem
> aumento salarial.

## 🏆 Troféus desbloqueados

| Troféu | Como conseguir |
|---|---|
| 🥉 **Hello, World** | Subir o primeiro `index.php` |
| 🥉 **Erro 500 com orgulho** | Ver o primeiro erro do PHP na tela (o `display_errors` está ligado, é de propósito) |
| 🥉 **Prefixo é lei** | Tentar criar um banco sem o prefixo `<nome>_` e ser barrado |
| 🥈 **Inquilino respeitoso** | Passar uma semana sem bater no limite de 3 GB de RAM |
| 🥈 **Mão no terminal** | Entrar por `ssh ps4` pela primeira vez |
| 🥈 **Ventoinha decolou** | Rodar algo pesado o bastante para a ventoinha do PS4 virar turbina |
| 🥇 **Sobrevivente** | Dar `DROP DATABASE` no banco errado e descobrir que só podia apagar os seus |
| 🏆 **Platina** | Entregar o projeto antes do prazo (ninguém conseguiu ainda) |

## O que o estagiário ganha

| Endereço | O que é |
|---|---|
| `estagiario1.rmo.dev.br/projeto1` | o site/projeto PHP ou HTML dele, para o mundo ver |
| `painel.rmo.dev.br` | gerenciador de arquivos web (cada um vê só a própria pasta) |
| `db.rmo.dev.br` | phpMyAdmin, com usuário próprio (o `DROP DATABASE` acidental só destrói o que é dele) |
| `ssh.rmo.dev.br` | SSH/SFTP, para os que já descobriram o terminal |

Na home, `public_html/` vai para o site e `privado/` nunca vai: lugar de
guardar o que não é para o mundo ver (anotações, backups, segredos do PHP).

> Usando este projeto? Troque `rmo.dev.br` pelo seu domínio.

## Tour pelo console

Prints tirados entrando como `estagiario1` (refaça com `node scripts/prints/tirar.mjs`).

**Login do painel:** usuário e senha na mesma tela, já cai na pasta do estagiário.

![Login do painel](docs/prints/painel-login.png)

**Painel de arquivos:** cada um vê só a própria home. `public_html` vai para o
site, `privado` nunca vai.

| Home | Dentro do `public_html` |
|---|---|
| ![Painel: home](docs/prints/painel-home.png) | ![Painel: public_html](docs/prints/painel-public_html.png) |

**Site do estagiário:** a página de boas-vindas que todo estagiário novo
recebe, com o passo a passo. Ele apaga quando subir o primeiro projeto.

![Página de boas-vindas](docs/prints/site-boas-vindas.png)

**phpMyAdmin:** em português, cada um com seu usuário e só os próprios bancos.

![phpMyAdmin](docs/prints/phpmyadmin.png)

**Subdomínio sem dono:** o PS4 avisa que o slot de save está vazio.

![Slot vazio](docs/prints/slot-vazio.png)

**No celular:**

| Login | Painel |
|---|---|
| <img src="docs/prints/celular-login.png" width="280" alt="Login no celular"> | <img src="docs/prints/celular-painel.png" width="280" alt="Painel no celular"> |

## Acesso por SSH

O SSH também passa pelo túnel da Cloudflare: não tem porta aberta no roteador
e funciona de qualquer lugar. O único requisito é o `cloudflared` no
computador de quem conecta, porque é ele que leva o `ssh` até o túnel.

### 1. Instalar o cloudflared (uma vez)

| Sistema | Comando |
|---|---|
| Windows (PowerShell) | `winget install --id Cloudflare.cloudflared` |
| macOS | `brew install cloudflared` |
| Linux (Debian/Ubuntu) | baixe o `.deb` em [github.com/cloudflare/cloudflared/releases](https://github.com/cloudflare/cloudflared/releases) e rode `sudo apt install ./cloudflared-linux-amd64.deb` |

No Windows, feche e abra o terminal depois de instalar. O `ssh` já vem no
Windows 10 e 11.

### 2. Criar sua chave SSH (estagiários)

As contas não têm senha de SSH (a do painel não serve aqui): o login é por
chave. Se o administrador preferir, ele pode criar uma senha de SSH para você.

```bash
ssh-keygen -t ed25519
```

Aperte Enter nas perguntas e mande para o administrador **só** o arquivo
`.pub` (no Windows: `C:\Users\<você>\.ssh\id_ed25519.pub`). O outro arquivo,
sem `.pub`, é secreto e não sai do seu computador.

O administrador cadastra com (passo a passo completo em
[docs/novo-estagiario.md](docs/novo-estagiario.md)):

```bash
scripts/chave-ssh.sh estagiario1 id_ed25519.pub
```

### 3. Conectar

```bash
ssh -o ProxyCommand="cloudflared access ssh --hostname %h" estagiario1@ssh.rmo.dev.br
```

Troque `estagiario1` pelo seu usuário.

### Atalho opcional: `ssh ps4`

Crie (ou edite) o arquivo `~/.ssh/config` (no Windows:
`C:\Users\<você>\.ssh\config`, sem extensão):

```
Host ps4
    HostName ssh.rmo.dev.br
    User estagiario1
    ProxyCommand cloudflared access ssh --hostname %h
```

Depois disso, funciona com o nome curto:

```bash
ssh ps4                          # terminal
scp index.php ps4:public_html/   # mandar arquivo
sftp ps4                         # SFTP (WinSCP também funciona)
```

No **VS Code**, instale a extensão *Remote - SSH*, aperte `F1`, escolha
"Remote-SSH: Connect to Host" e selecione `ps4`.

### Deu `CreateProcessW failed error:2` no Windows?

O `ssh` não achou o `cloudflared`. Confira com `Get-Command cloudflared`:

1. Se não encontrar, instale (`winget install --id Cloudflare.cloudflared`) e
   **feche e abra o PowerShell** antes de tentar de novo.
2. Se ainda assim não achar, descubra onde ele está:
   ```powershell
   Get-ChildItem -Recurse -Filter cloudflared.exe "C:\Program Files*", "$env:LOCALAPPDATA\Microsoft\WinGet" -ErrorAction SilentlyContinue | Select-Object -First 1 FullName
   ```
   e use o caminho completo, entre aspas, no `ProxyCommand` do `~/.ssh/config`:
   ```
   ProxyCommand "C:\Program Files (x86)\cloudflared\cloudflared.exe" access ssh --hostname %h
   ```

`Permission denied (publickey,password)` quer dizer que o túnel funcionou e
falta a chave: mande seu `.pub` para o administrador.

## Ficha técnica do "datacenter"

| Item | Especificação |
|---|---|
| Servidor | PlayStation 4, aposentado do sofá e promovido a servidor de produção sem ninguém perguntar a opinião dele |
| CPU | AMD Jaguar, 8 núcleos (os mesmos que faziam 30 fps no Bloodborne, quando estavam de bom humor) |
| GPU | Radeon com 32 CUs que já renderizou Los Santos inteira e agora fica olhando para o teto enquanto o PHP trabalha |
| RAM | 7,6 GB, compartilhados com a GPU, dividindo como irmãos no banco de trás |
| Swap | zram: a RAM comprime a própria RAM. É tipo guardar roupa em saco a vácuo, só que com bytes |
| Disco | um arquivo `.img` dentro do HD do PS4. É Linux dentro de um arquivo dentro de um console. Inception de pobre |
| Rede | Wi-Fi/cabo de casa, IP dinâmico, NAT, e a fé inabalável na Cloudflare |
| Refrigeração | a ventoinha do PS4, que soa como um Boeing decolando sempre que alguém roda `composer install` |
| Localização | estante da sala, entre um controle sem bateria e um fone que só funciona de um lado |
| Uptime | até alguém tropeçar no cabo, ou o Ricardo decidir jogar RetroArch ou algum joguinho de plataforma 2D |
| SLA | "funciona na minha casa" |
| Backup | está no roadmap desde o primeiro commit, como todo backup que se preze |
| Suporte | gritar "RICARDO" pela casa |

## Como funciona

```
Internet ─► Cloudflare (DNS + HTTPS) ─► Cloudflare Tunnel ─► PS4 na estante
                                                              │
                         ┌────────────────────────────────────┤
                         ▼                                    ▼
                  nginx (roteia por subdomínio)          SSH / SFTP
                    │            │
       container PHP do      container PHP do       File Browser, phpMyAdmin
         estagiario1           estagiario2                  │
              │                     │                        ▼
        /home/estagiario1     /home/estagiario2           MariaDB
        (disco de 50 GB)      (disco de 50 GB)
```

O túnel da Cloudflare sai de dentro do PS4 para a internet, então não precisa
de IP fixo nem abrir porta no roteador. O roteador nem fica sabendo que virou
provedor de hospedagem. Se a operadora perguntar, é só um PS4 baixando
atualização. Há três anos.

Detalhes e o porquê de cada escolha: [docs/arquitetura.md](docs/arquitetura.md).

## Limites por estagiário

Porque a RAM é finita e o entusiasmo do estagiário, não.

| Recurso | Limite | Como é aplicado |
|---|---|---|
| Disco | 50 GB | disco virtual próprio montado como `/home/<nome>` |
| RAM | 3 GB (SSH + containers somados) | systemd `user-<UID>.slice` com `MemoryMax` |
| Banco | só bancos `<nome>_*` | usuário MariaDB com permissão por prefixo |

Passou do limite? O kernel encerra o processo do estagiário, e só o dele.
O PS4 e o colega continuam firmes. É o equivalente digital de "quem quebrou,
paga", só que sem o boleto.

O loop infinito de um estagiário nunca derruba o site do outro. Já o loop
infinito do Ricardo pode derrubar tudo, mas aí é gestão.

## Requisitos

- Linux com systemd e cgroup v2 (testado no Ubuntu 26.04)
- Docker com cgroup driver `systemd` e Docker Compose
- Domínio com DNS na Cloudflare (plano Free basta)
- Um PS4 é opcional, mas recomendado pelo estilo. Para transformar o seu em
  servidor, siga o [ubuntu-server-on-ps4](https://github.com/Roliveira96/ubuntu-server-on-ps4) até a pós-instalação
- Um PS5 também serve, mas aí você é rico e devia estar pagando a AWS

## Como montar do zero

Siga [docs/instalacao.md](docs/instalacao.md). O começo:

```bash
cp .env.example .env                       # preencha domínio e senha do MariaDB
sudo scripts/configurar-sistema.sh         # swap em zram (uma vez por máquina)

# cria o estagiário (usuário, disco de 50 GB, 3 GB de RAM) e já liga tudo dele
sudo scripts/novo-estagiario.sh estagiario1

scripts/estagio ps                         # docker compose do projeto inteiro
```

As senhas geradas ficam em `credenciais/<nome>.txt`, fora do Git.

> 📋 **Chegou estagiário novo?** Siga o
> [checklist passo a passo](docs/novo-estagiario.md): criar a conta, liberar
> o SSH, conferir e a mensagem pronta para mandar a ele.

### Logins de cada estagiário

São três logins separados. A senha de um não serve no outro.

| Onde | Usuário | Senha |
|---|---|---|
| Painel (`painel.<dominio>`) | `<nome>` | `PAINEL_SENHA` em `credenciais/<nome>.txt` |
| Banco / phpMyAdmin (`db.<dominio>`) | `<nome>` | `BANCO_SENHA` em `credenciais/<nome>.txt` |
| SSH (`ssh.<dominio>`) | `<nome>` | nenhuma: a conta não tem senha |

Para ver as senhas de alguém:

```bash
cat credenciais/estagiario1.txt
```

Para o SSH há dois caminhos:

- **Chave SSH (recomendado):** o estagiário manda o `.pub` e você roda
  `scripts/chave-ssh.sh <nome> id_ed25519.pub`. Veja "Acesso por SSH".
- **Senha de SSH:** mais simples para quem está começando:
  ```bash
  sudo passwd <nome>
  ```
  O SSH só é alcançável pelo túnel (nenhuma porta aberta), o que reduz o
  risco, mas uma senha fraca ou vazada ainda deixa entrar.

## Estrutura

```
compose.yaml        serviços compartilhados: nginx, MariaDB, phpMyAdmin, túnel
estagiarios/        modelo dos containers de cada estagiário (web + painel)
imagens/php/        imagem Apache + PHP 8.3 que roda como o estagiário
proxy/              config do nginx, tela de login do painel e páginas temáticas
modelos/            página de boas-vindas que cada estagiário recebe
config/             phpMyAdmin (português) e sistema (swap em zram)
apps/               modelo dos apps Go do administrador (scripts/novo-app.sh)
servicos/           NAS estilo Google Drive (Cloudreve), entra depois do disco do NAS
scripts/            configurar-sistema.sh, configurar-nas.sh e novo-estagiario.sh (sudo),
                    ativar-estagiario.sh, chave-ssh.sh, nas.py, estagio,
                    novo-app.sh e remover-app.sh (apps Go)
scripts/prints/     tira os prints deste README entrando como estagiário
docs/               arquitetura, instalação e prints
credenciais/, .env  senhas (ignorados pelo Git)
```

## Progresso da campanha

- [x] Swap comprimida na RAM (zram)
- [x] Script de criação de estagiário (usuário, disco, RAM)
- [x] Criar `estagiario1` e `estagiario2` no servidor
- [x] Domínio `rmo.dev.br` apontado para a Cloudflare
- [x] Cloudflare Tunnel (`*.rmo.dev.br` no ar)
- [x] nginx + container PHP 8.3 por estagiário
- [x] MariaDB + phpMyAdmin com usuário por estagiário
- [x] File Browser (painel), um por estagiário
- [x] SSH pelo túnel (`ssh.rmo.dev.br`)
- [x] Apps Go do administrador em subdomínio ou domínio próprio, sem Dockerfile ([docs/apps-go.md](docs/apps-go.md))
- [ ] SSH dos estagiários num container isolado (hoje cai no sistema do servidor)
- [ ] Login por e-mail (Cloudflare Access) na frente do SSH e do phpMyAdmin
- [ ] Bloqueio da rede interna para os estagiários
- [ ] NAS estilo Google Drive (Cloudreve) em `nas.rmo.dev.br`: scripts prontos e testados num Cloudreve temporário; falta rodar `sudo scripts/configurar-nas.sh` e `scripts/nas.py iniciar`

## Segredos

Nenhuma senha, token ou chave vive neste repositório. Elas ficam em arquivos
`.env` ignorados pelo Git; o repositório só traz `.env.example` mostrando o que
preencher. Se achar uma senha aqui, abra uma issue. E um chamado no RH. E
troque a senha, porque a essa altura ela já está num print do grupo da família.

## 📜 Notas de atualização

**v1.04: "O Despertar do Console"**
- Adicionado suporte a estagiários. Antes eram só jogos, o que era bem mais barato.
- Corrigido bug em que o PS4 achava que ainda era um videogame.
- O PHP agora roda como o próprio estagiário. Erros também são dele agora.
- Adicionada swap em zram. A RAM aprendeu a fazer origami.
- O administrador agora também hospeda os próprios apps Go. O PS4 passou a
  compilar Go com a mesma CPU que um dia renderizou o Kratos. Ele não reclama,
  só gira a ventoinha.
- Removido o modo "Descanso". Servidor não descansa. Estagiário também não, mas esse bug é do RH.
- Problemas conhecidos: o Ricardo às vezes quer jogar Celeste. Sem previsão de correção.

## FAQ

**Isso é sério?**
O PS4 é sério. A infra é séria. A gente só não consegue falar dela com a cara séria.

**Aguenta quantos estagiários?**
Uns 3 a 5 com projetos leves. Depois disso o PS4 começa a fazer o barulho de
quando você abria o Red Dead 2.

**Por que não um Raspberry Pi?**
O Raspberry Pi não tem 8 núcleos, nem GDDR5, nem a trilha sonora do God of War
na memória afetiva. Além disso, ele não estava parado na estante.

**E se a energia cair?**
Aí todo mundo descobre ao mesmo tempo o que significa "alta disponibilidade".
Spoiler: não temos.

**Dá para jogar enquanto hospeda?**
Não. Ele está rodando Linux. O console agora trabalha. O máximo de diversão
permitida é um RetroArch quando o Ricardo jura que "é rapidinho".

**O site caiu. O que eu faço?**
1. Respire.
2. Veja se alguém tropeçou no cabo.
3. Veja se o Ricardo está jogando.
4. Só então abra os logs (`scripts/estagio logs -f web-<nome>`).

**O estagiário pode instalar o Fortnite no servidor?**
Pode tentar. São 3 GB de RAM, 50 GB de disco e nenhuma placa de vídeo
liberada. Boa sorte, campeão.

**Meu projeto está lento. É o PS4?**
Provavelmente é o `SELECT *` sem `WHERE` dentro de um `foreach`. Mas pode
culpar o PS4, ele aguenta. Já aguentou coisa pior.

**A Sony sabe disso?**
Não. E vamos manter assim.

---

<sub>Feito com carinho, café e um console que merecia aposentadoria. Nenhum
estagiário foi alocado em produção sem supervisão. Pelo menos não de propósito.</sub>
