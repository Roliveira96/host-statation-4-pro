# Arquitetura e decisões

## Servidor atual

Um PlayStation 4 rodando Ubuntu 26.04 (kernel PS4 "Strawberry"):

- CPU AMD Jaguar de 8 núcleos, 7,6 GB de RAM, sem swap
- Disco raiz é um arquivo de imagem (`/dev/loop0`, ext4) no HD do PS4
- Fica na rede de casa, sem IP público fixo

Nada aqui depende de ser um PS4. As particularidades dele estão marcadas como
**(PS4)** para saber o que muda numa máquina comum.

## Acesso pela internet: Cloudflare Tunnel

O `cloudflared` abre uma conexão de dentro do servidor para a Cloudflare.
Assim não precisa de IP fixo nem abrir porta no roteador. O HTTPS fica por
conta da Cloudflare.

Um registro DNS coringa `*.rmo.dev.br` aponta para o túnel, então um
estagiário novo não exige mexer no DNS. O domínio principal e o `www` têm
registros próprios (site pessoal na Hostinger) e por isso não passam pelo
PS4: registro específico sempre ganha do coringa.

Nomes reservados, que não podem ser usados como nome de estagiário: `www`,
`painel`, `db`, `ssh`, `api`, `mail` (o script recusa).

O certificado gratuito cobre um nível de subdomínio (`algo.rmo.dev.br`).
Por isso:

- projetos ficam em caminho: `estagiario1.rmo.dev.br/projeto1`
- serviços extras usam hífen: `api-estagiario1.rmo.dev.br`
- underline não é válido em nome de domínio

## Disco: um disco virtual de 50 GB por estagiário

**(PS4)** O kernel não tem `CONFIG_QUOTA`, então cota de disco do sistema
não funciona. Em vez disso, cada estagiário tem um arquivo de imagem ext4 em
`/srv/estagio/discos/<nome>.img`, montado como `/home/<nome>` via `/etc/fstab`.

- O arquivo é esparso: só ocupa no HD o que foi usado de fato.
- A montagem usa `discard`, então arquivos apagados devolvem espaço ao HD.
- Quando enche, só aquele estagiário é afetado.

Numa máquina com quota no kernel isso continua funcionando; trocar por quota
é opcional.

## RAM: 3 GB por estagiário, somando tudo

Os processos das sessões SSH de um usuário ficam em `user-<UID>.slice`.
O script coloca um `MemoryMax` nessa slice, e os containers do estagiário
usam `cgroup_parent: user-<UID>.slice`, então SSH e containers dividem o
mesmo teto. Passou do limite, o kernel encerra o processo daquele estagiário
sem afetar os outros.

Requer Docker com cgroup driver `systemd` (`docker info` mostra
`Cgroup Driver: systemd`).

**(PS4)** Sem swap e com 7,6 GB, dois estagiários no limite (6 GB) mais os
serviços já deixam o servidor apertado. Dá para mudar o limite rodando o
script de novo com outro valor.

## Isolamento entre estagiários

- Home com permissão `750`: um não lê os arquivos do outro.
- Um container PHP por estagiário, rodando com o UID dele e enxergando só a
  pasta dele.
- Banco: cada um tem usuário MariaDB próprio e só acessa bancos com o prefixo
  `<nome>_`.
- Estagiários nunca entram no grupo `docker` (equivale a ser root).
- Usuários Linux são criados sem senha; acesso por chave SSH ou pelo painel.

## Projetos do administrador (fora deste repositório)

Projetos maiores do administrador (com banco, filas etc.) vivem no git deles e
só se plugam aqui:

- **Rota:** o projeto grava um arquivo em `proxy/apps/<projeto>.conf` (fora do
  Git) com `server_name` exato; o nginx inclui todos. Nome exato ganha do
  coringa `<estagiário>.<dominio>`, e a rota coringa do túnel já traz qualquer
  subdomínio de um nível.
- **Rede:** os containers públicos do projeto entram na rede `estagio-apps`,
  onde só está o nginx. Os containers dos estagiários ficam na `estagio` e não
  enxergam esses projetos; o resto do projeto fica numa rede interna dele.
- **Portas:** nada de porta pública no host (80 é do nginx, 3306 do MariaDB);
  painéis internos só em `127.0.0.1`.
- **RAM:** o projeto roda numa slice própria com teto (`cgroup_parent`), como
  os estagiários.

Exemplo: o CamperSite, com o deploy em `deploy/ps4/` do
[repositório dele](https://github.com/Roliveira96/system-for-campers-and-caravanners).
