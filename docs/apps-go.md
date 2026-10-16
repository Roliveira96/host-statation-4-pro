# Apps Go do administrador

Projetos Go **seus** (não dos estagiários) rodando no PS4, num subdomínio
(`loja.rmo.dev.br`) ou num domínio próprio (`meusite.com.br`). Sem
Dockerfile, sem registry e sem VPS.

## Como funciona

```
loja.rmo.dev.br ─► Cloudflare ─► túnel ─► estagio-proxy (nginx) ─► app-loja:8080
```

- O container `app-<nome>` usa a imagem oficial `golang:1.27-alpine`, com a
  pasta do projeto montada **só leitura** em `/app`. A cada (re)início ele faz
  `go build` e roda o binário. Nenhuma imagem é criada.
- O cache de compilação e de módulos fica em `~/.cache/estagio-go`, então só o
  primeiro build é lento (a CPU é de 2013, tenha fé).
- Roda com o seu usuário, com limite de memória (`MEMORIA`, padrão `512m`).
- Está na rede `estagio`: o banco é `mariadb:3306`.
- Enquanto compila (ou se cair), o site mostra uma página de "compilando".

## Requisitos do projeto

- `go.mod` na raiz e o `main` também na raiz (`go build .`).
- O app ouve na porta da variável `PORT` (padrão `8080`):
  `http.ListenAndServe(":"+os.Getenv("PORT"), nil)`.
- Variáveis do projeto: um `.env` na pasta do projeto é carregado
  automaticamente (fica fora do Git do projeto, claro).
- `go.sum` completo: o código é só leitura, o build não consegue atualizá-lo.
  Rode `go mod tidy` antes.

## Publicar

```bash
scripts/novo-app.sh loja ~/apps/loja loja                     # loja.rmo.dev.br
scripts/novo-app.sh loja ~/apps/loja loja meusite.com.br www.meusite.com.br
PORTA=3000 MEMORIA=1g scripts/novo-app.sh loja ~/apps/loja loja
```

Endereço sem ponto vira `<endereço>.<DOMINIO>`; com ponto é domínio completo.
Rodar de novo com outros endereços ou limites refaz tudo.

O script recusa:

- subdomínio de dois níveis (`api.loja.rmo.dev.br`): o certificado grátis da
  Cloudflare só cobre um nível. Use hífen: `api-loja.rmo.dev.br`;
- nomes reservados (`www`, `painel`, `db`, `nas`, `ssh`, `mail`) e nomes de
  estagiários;
- o domínio principal (`rmo.dev.br`), que aponta para o site na Hostinger.

### Subdomínio do `rmo.dev.br`

Nada a fazer na Cloudflare: a rota coringa `*` do túnel já traz para o nginx,
e o nome exato do app ganha do coringa dos estagiários.

### Domínio próprio

1. O domínio precisa estar na **mesma conta** da Cloudflare (adicione e troque
   os nameservers no registrador, como no passo 4 de
   [instalacao.md](instalacao.md)).
2. No túnel, **Routes > Add route > Published application**, uma rota por nome:

   | Subdomain | Domain | Service URL |
   |---|---|---|
   | (vazio) | `meusite.com.br` | `http://estagio-proxy:80` |
   | `www` | `meusite.com.br` | `http://estagio-proxy:80` |

   Se já existir registro A/CNAME para esse nome, apague antes: a Cloudflare
   cria o CNAME do túnel sozinha.

## Dia a dia

```bash
scripts/estagio restart app-loja     # depois de mudar o código: recompila e sobe
scripts/estagio logs -f app-loja     # erros de build e do app
scripts/remover-app.sh loja          # tira do ar (o código não é apagado)
```

Os arquivos gerados (`apps/<nome>.yaml` e `proxy/apps/<nome>.conf`) ficam fora
do Git, como os dos estagiários.
