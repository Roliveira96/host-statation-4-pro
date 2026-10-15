# Estágio — hospedagem para estagiários

Infraestrutura para cada estagiário ter seu próprio espaço de hospedagem
(estilo Hostinger), rodando num servidor caseiro e acessível pela internet
sem IP fixo.

- `estagiario1.rmo.dev.br/projeto1` → site/projeto PHP ou HTML do estagiário
- `painel.rmo.dev.br` → gerenciador de arquivos web (cada um vê só a sua pasta)
- `db.rmo.dev.br` → phpMyAdmin (cada um com seu usuário de banco)
- `ssh.rmo.dev.br` → SSH/SFTP (opcional)

Tudo que configura o servidor está neste repositório, para dar para
recriar o ambiente em outra máquina rodando os mesmos passos.

## Arquitetura

```
Internet ─► Cloudflare (DNS + HTTPS) ─► Cloudflare Tunnel ─► servidor
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

Detalhes e o porquê de cada escolha: [docs/arquitetura.md](docs/arquitetura.md).

## Limites por estagiário

| Recurso | Limite | Como é aplicado |
|---|---|---|
| Disco | 50 GB | disco virtual próprio montado como `/home/<nome>` |
| RAM | 3 GB (SSH + containers somados) | systemd `user-<UID>.slice` com `MemoryMax` |
| Banco | só bancos `<nome>_*` | usuário MariaDB com permissão por prefixo |

## Requisitos

- Linux com systemd e cgroup v2 (testado no Ubuntu 26.04)
- Docker com cgroup driver `systemd` e Docker Compose
- Domínio com DNS na Cloudflare (plano Free basta)

## Como montar do zero

Siga [docs/instalacao.md](docs/instalacao.md). Resumo:

```bash
# 1. criar cada estagiário (usuário, disco de 50 GB, limite de 3 GB de RAM)
sudo scripts/novo-estagiario.sh estagiario1
sudo scripts/novo-estagiario.sh estagiario2
```

## Estrutura

```
scripts/   scripts de administração (rodar com sudo)
docs/      documentação: arquitetura, instalação, operação
```

## Status

- [x] Script de criação de estagiário (usuário, disco, RAM)
- [ ] Criar `estagiario1` e `estagiario2` no servidor
- [ ] Domínio `rmo.dev.br` ativo na Cloudflare
- [ ] Cloudflare Tunnel
- [ ] nginx + container PHP por estagiário
- [ ] MariaDB + phpMyAdmin com usuário por estagiário
- [ ] File Browser (painel)
- [ ] SSH protegido pelo Cloudflare Access
- [ ] Bloqueio da rede interna para os estagiários
