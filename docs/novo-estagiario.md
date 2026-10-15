# 📋 Checklist: chegou estagiário novo

Anotação para o Ricardo do futuro, que já esqueceu tudo isso. Siga na ordem.
Tempo total: uns 10 minutos, mais o tempo de o estagiário achar o arquivo `.pub`.

Tudo é rodado **no PS4**, dentro da pasta do projeto:

```bash
cd ~/estagio
```

Nada precisa ser feito no painel da Cloudflare: o DNS coringa (`*.rmo.dev.br`)
e a rota `ssh.rmo.dev.br` já atendem qualquer estagiário novo.

---

## 1. Escolher o nome de usuário

Vai virar o subdomínio do site e o login de tudo: `<nome>.rmo.dev.br`.

- Só letras minúsculas, números e hífen, começando com letra: `joao`,
  `maria-silva`, `estagiario3`.
- Sem acento, sem espaço, sem underline.
- Nomes reservados (o script recusa): `www`, `painel`, `db`, `ssh`, `api`, `mail`.

Nos exemplos abaixo, troque `joao` pelo nome escolhido.

## 2. Criar a conta

```bash
sudo scripts/novo-estagiario.sh joao
```

Isso faz tudo de uma vez:

- [ ] usuário Linux `joao`, sem senha
- [ ] disco próprio de 50 GB em `/home/joao` (com `public_html/` e `privado/`)
- [ ] limite de 3 GB de RAM
- [ ] site em `https://joao.rmo.dev.br`, com a página de boas-vindas
- [ ] painel de arquivos com login e senha
- [ ] usuário no banco, com acesso só aos bancos `joao_*`

Quer outro tamanho? `sudo scripts/novo-estagiario.sh joao 20G 2G` (disco e RAM).

## 3. Pegar as senhas geradas

```bash
cat credenciais/joao.txt
```

Guarde `PAINEL_SENHA` e `BANCO_SENHA` para mandar ao estagiário no passo 6.

## 4. Liberar o SSH

O estagiário **não tem senha de SSH**. A senha do painel não serve no SSH.
Escolha um dos dois caminhos:

### Caminho A: chave SSH (recomendado)

1. Peça ao estagiário para rodar, no computador dele:
   ```bash
   ssh-keygen -t ed25519
   ```
   e te mandar **só** o arquivo `id_ed25519.pub`. No Windows ele fica em
   `C:\Users\<usuario-dele>\.ssh\id_ed25519.pub`.

   > ⚠️ Se ele mandar o arquivo **sem** `.pub`, isso é a chave secreta dele.
   > Não use: peça para ele gerar uma nova e mandar só o `.pub`.

2. Coloque o arquivo no PS4 (por exemplo em `~/joao.pub`) e cadastre:
   ```bash
   scripts/chave-ssh.sh joao ~/joao.pub
   ```
   Também dá para colar o conteúdo direto, entre aspas:
   ```bash
   scripts/chave-ssh.sh joao "ssh-ed25519 AAAAC3Nza... joao@notebook"
   ```
   O script recusa o que não for chave pública e não duplica se rodar duas vezes.

3. Se ele trocar de computador, é só repetir com a chave nova. As antigas
   continuam valendo.

### Caminho B: senha de SSH (mais simples, menos seguro)

```bash
sudo passwd joao
```

Use uma senha forte e diferente da do painel. O SSH só é alcançável pelo
túnel da Cloudflare, mas uma senha vazada ainda deixa entrar.

## 5. Conferir se ficou tudo certo

```bash
scripts/estagio ps | grep joao                    # web-joao e painel-joao rodando
curl -s https://joao.rmo.dev.br/ | grep "<h1>"    # "Olá, joao!"
sudo cat /home/joao/.ssh/authorized_keys          # a chave dele (se usou o caminho A)
```

O teste final do SSH é o estagiário conectar (passo 6). Se ele receber
`Permission denied (publickey,password)`, o túnel está funcionando e o
problema é a chave ou a senha: volte ao passo 4.

## 6. Mandar as boas-vindas

Copie, troque os campos e mande para ele:

```text
Bem-vindo(a) ao PlayStagiário 4! Seu espaço no servidor está pronto.

🌐 Seu site: https://joao.rmo.dev.br
   Cada pasta dentro de public_html vira um endereço:
   public_html/loja → https://joao.rmo.dev.br/loja

📁 Painel de arquivos: https://painel.rmo.dev.br
   Usuário: joao
   Senha: <PAINEL_SENHA>

🗄️ Banco de dados (phpMyAdmin): https://db.rmo.dev.br
   Usuário: joao
   Senha: <BANCO_SENHA>
   Seus bancos precisam começar com joao_ (ex.: joao_loja).
   No PHP, o servidor do banco é "mariadb", porta 3306.

💻 SSH (terminal, VS Code, SFTP): siga a seção "Acesso por SSH" em
   https://github.com/Roliveira96/host-statation-4-pro#acesso-por-ssh
   Comando: ssh -o ProxyCommand="cloudflared access ssh --hostname %h" joao@ssh.rmo.dev.br

🔒 A pasta "privado" nunca aparece no site; use para o que não é público.
Limites: 50 GB de disco e 3 GB de RAM.
```

Mande as senhas por um canal privado (mensagem direta), nunca num grupo.

---

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| Site mostra "Nenhum estagiário salvo neste slot" | Container parado: `scripts/estagio up -d web-joao painel-joao` |
| Painel diz "Usuário ou senha incorretos" | Confira `PAINEL_SENHA` em `credenciais/joao.txt` (maiúsculas contam) |
| Windows: `CreateProcessW failed error:2` | Falta o `cloudflared` no PC dele; veja o README |
| SSH: `Permission denied` | Chave não cadastrada ou errada: passo 4 |
| Esqueceu a senha do painel | Por enquanto não tem script para trocar; peça ao Claude 😅 |

## Quando o estágio acabar

Ainda não existe script para remover estagiário (`a fazer`). Até lá, para
bloquear o acesso sem apagar nada:

```bash
scripts/estagio stop web-joao painel-joao   # site e painel fora do ar
sudo usermod -L -e 1 joao                   # bloqueia o login (SSH inclusive)
```
