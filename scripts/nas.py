#!/usr/bin/env python3
"""NAS estilo Google Drive (Cloudreve): configura o site e mantém os usuários.

Roda sem sudo, depois de `sudo scripts/configurar-nas.sh` e de o container
estar no ar (`scripts/estagio up -d nas proxy`).

    scripts/nas.py iniciar              # 1ª vez: cria o admin (você), fecha o cadastro
    scripts/nas.py adicionar <nome>     # cria usuário + pasta "Público" + atalhos
    scripts/nas.py sincronizar          # refaz os atalhos "Públicos da galera" entre todos

Cada usuário tem:
  - "Meus arquivos": privado, só ele vê;
  - "Público": compartilhado com os outros usuários (só leitura para eles);
  - "Públicos da galera": atalhos para o "Público" de cada colega.
Ninguém vê nada sem login. Senhas ficam em credenciais/<nome>.txt (fora do Git).
"""
import base64
import getpass
import json
import os
import secrets
import string
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CRED = RAIZ / "credenciais"
COTA_GB = int(os.environ.get("NAS_COTA_GB", "20"))  # por usuário (grupo "User")
PUBLICO = "Público"
GALERA = "Públicos da galera"
GRUPO_USER, GRUPO_ANONIMO = 2, 3
BIT_BAIXAR_COMPARTILHADO = 7  # permissão do Cloudreve: acessar links de compartilhamento


def env():
    valores = {}
    for linha in (RAIZ / ".env").read_text().splitlines():
        if "=" in linha and not linha.lstrip().startswith("#"):
            k, v = linha.split("=", 1)
            valores[k.strip()] = v.strip()
    return valores


DOMINIO = env()["DOMINIO"]
HOST = f"nas.{DOMINIO}"


# ---------- credenciais/<nome>.txt ----------

def ler_cred(nome):
    arq = CRED / f"{nome}.txt"
    if not arq.exists():
        return {}
    return dict(l.split("=", 1) for l in arq.read_text().splitlines() if "=" in l and not l.startswith("#"))


def garantir_cred(nome):
    """Cria login e senha do NAS para <nome>, se ainda não existirem."""
    cred = ler_cred(nome)
    if "NAS_SENHA" in cred:
        return cred
    CRED.mkdir(mode=0o700, exist_ok=True)
    arq = CRED / f"{nome}.txt"
    alfabeto = string.ascii_letters + string.digits
    novo = {
        "NAS_URL": f"https://{HOST}",
        "NAS_LOGIN": f"{nome}@{DOMINIO}",
        "NAS_SENHA": "".join(secrets.choice(alfabeto) for _ in range(16)),
    }
    cabecalho = "" if arq.exists() else f"# PlayStagiário 4 · credenciais de {nome} (NÃO vai para o Git)\n"
    fd = os.open(arq, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(fd, "a") as f:
        f.write(cabecalho + "".join(f"{k}={v}\n" for k, v in novo.items()))
    return {**cred, **novo}


def participantes():
    return sorted(a.stem for a in CRED.glob("*.txt") if "NAS_LOGIN" in ler_cred(a.stem))


# ---------- API do Cloudreve (pelo nginx local, com o Host do NAS) ----------

class ErroAPI(Exception):
    pass


def api(metodo, caminho, token=None, corpo=None, params=None):
    url = "http://127.0.0.1/api/v4" + caminho
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, method=metodo, headers={"Host": HOST, "Content-Type": "application/json"})
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    dados = json.dumps(corpo).encode() if corpo is not None else None
    try:
        with urllib.request.urlopen(req, dados, timeout=60) as r:
            resp = json.load(r)
    except urllib.error.HTTPError as e:
        raise ErroAPI(f"{metodo} {caminho}: HTTP {e.code}") from None
    if resp.get("code") != 0:
        raise ErroAPI(f"{metodo} {caminho}: {resp.get('msg')} (código {resp.get('code')})")
    return resp.get("data")


def esperar_nas():
    for _ in range(60):
        try:
            api("GET", "/site/ping")
            return
        except (ErroAPI, OSError):
            time.sleep(3)
    sys.exit("o NAS não respondeu. Está rodando? scripts/estagio up -d nas proxy")


def login(cred):
    dados = api("POST", "/session/token", corpo={"email": cred["NAS_LOGIN"], "password": cred["NAS_SENHA"]})
    return dados["token"]["access_token"], dados["user"]


def listar(token, uri):
    return api("GET", "/file", token, params={"uri": uri, "page_size": 500})["files"]


# ---------- operações ----------

def garantir_publico(nome):
    """Pasta "Público" do usuário + link de compartilhamento. Devolve o id do link."""
    token, _ = login(ler_cred(nome))
    if PUBLICO not in {f["name"] for f in listar(token, "cloudreve://my")}:
        api("POST", "/file/create", token, {"type": "folder", "uri": f"cloudreve://my/{PUBLICO}"})
    for s in (api("GET", "/share", token, params={"page_size": 100}) or {}).get("shares", []):
        if s.get("name") == PUBLICO and not s.get("expired"):
            return s["id"]
    url = api("PUT", "/share", token, {"uri": f"cloudreve://my/{PUBLICO}", "is_private": False, "share_view": True})
    return url.rstrip("/").rsplit("/", 1)[-1]


def sincronizar():
    nomes = participantes()
    links = {n: garantir_publico(n) for n in nomes}
    for nome in nomes:
        token, _ = login(ler_cred(nome))
        if GALERA not in {f["name"] for f in listar(token, "cloudreve://my")}:
            api("POST", "/file/create", token, {"type": "folder", "uri": f"cloudreve://my/{GALERA}"})
        existentes = {f["name"] for f in listar(token, f"cloudreve://my/{GALERA}")}
        for outro in nomes:
            if outro == nome or outro in existentes:
                continue
            api("POST", "/file/create", token, {
                "type": "folder",
                "uri": f"cloudreve://my/{GALERA}/{outro}",
                "metadata": {"sys:shared_redirect": f"cloudreve://{links[outro]}@share"},
            })
            print(f"   {nome}: atalho para o Público de {outro}")
    print(f"   sincronizado: {', '.join(nomes)}")


def iniciar(admin):
    esperar_nas()
    cred = garantir_cred(admin)
    try:
        token, usuario = login(cred)
    except ErroAPI:
        # O primeiro cadastro do Cloudreve vira administrador
        api("POST", "/user", corpo={"email": cred["NAS_LOGIN"], "password": cred["NAS_SENHA"], "language": "pt-BR"})
        token, usuario = login(cred)
    if usuario["group"]["name"] != "Admin":
        sys.exit(f"{admin} não é administrador do NAS: alguém se cadastrou antes. Recrie o NAS do zero.")

    api("PATCH", "/admin/settings", token, {"settings": {
        "register_enabled": "0",                  # só o admin cria contas
        "siteName": "NAS · PlayStagiário 4",
        "siteURL": f"https://{HOST}",
    }})
    # Visitante sem login não abre link de compartilhamento: o "Público" é só entre usuários
    anonimo = api("GET", f"/admin/group/{GRUPO_ANONIMO}", token)
    bits = bytearray(base64.b64decode(anonimo["permissions"] or ""))
    if len(bits) > BIT_BAIXAR_COMPARTILHADO // 8:
        bits[BIT_BAIXAR_COMPARTILHADO // 8] &= ~(1 << BIT_BAIXAR_COMPARTILHADO % 8) & 0xFF
    anonimo["permissions"] = base64.b64encode(bytes(bits)).decode()
    api("PUT", f"/admin/group/{GRUPO_ANONIMO}", token, {"group": anonimo})
    # Cota de cada usuário comum
    grupo = api("GET", f"/admin/group/{GRUPO_USER}", token)
    grupo["max_storage"] = COTA_GB * 1024**3
    api("PUT", f"/admin/group/{GRUPO_USER}", token, {"group": grupo})

    print(f"   admin {cred['NAS_LOGIN']} pronto; cadastro fechado; cota de {COTA_GB} GB por usuário")
    sincronizar()


def adicionar(nome, admin):
    esperar_nas()
    token, _ = login(ler_cred(admin))
    cred = garantir_cred(nome)
    try:
        login(cred)
        print(f"   {nome} já existia no NAS")
    except ErroAPI:
        api("PUT", "/admin/user", token, {
            "user": {"email": cred["NAS_LOGIN"], "nick": nome, "status": "active",
                     "group_users": GRUPO_USER, "settings": {}},
            "password": cred["NAS_SENHA"],
        })
        print(f"   {nome} criado no NAS (login {cred['NAS_LOGIN']})")
    sincronizar()


if __name__ == "__main__":
    admin = os.environ.get("NAS_ADMIN", getpass.getuser())
    match sys.argv[1:]:
        case ["iniciar"]:
            iniciar(admin)
        case ["adicionar", nome]:
            adicionar(nome, admin)
        case ["sincronizar"]:
            esperar_nas()
            sincronizar()
        case _:
            sys.exit(__doc__)
