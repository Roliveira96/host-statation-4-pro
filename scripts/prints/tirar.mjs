// Tira os prints do README entrando no sistema como um estagiário.
// Usa o Firefox instalado na máquina (sem baixar navegador).
//
//   cd scripts/prints && npm install
//   node tirar.mjs estagiario1
//
// Lê as senhas de credenciais/<usuario>.txt e salva em docs/prints/.
import puppeteer from 'puppeteer-core';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const usuario = process.argv[2] ?? 'estagiario1';
const saida = path.join(raiz, 'docs/prints');
const env = Object.fromEntries(
  readFileSync(path.join(raiz, '.env'), 'utf8').split('\n')
    .concat(readFileSync(path.join(raiz, 'credenciais', `${usuario}.txt`), 'utf8').split('\n'))
    .filter(l => /^[A-Z_]+=/.test(l))
    .map(l => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)])
);
const dominio = env.DOMINIO;
const espera = ms => new Promise(r => setTimeout(r, ms));

const browser = await puppeteer.launch({
  browser: 'firefox',
  executablePath: process.env.FIREFOX ?? '/usr/bin/firefox',
  headless: true,
});
const page = await browser.newPage();
const tamanho = (width, height) => page.setViewport({ width, height });
const ir = async url => { await page.goto(url, { waitUntil: 'networkidle0' }); await espera(800); };
const print = async nome => {
  await page.screenshot({ path: path.join(saida, `${nome}.png`) });
  console.log('ok', nome);
};

await tamanho(1280, 800);

// Login do painel: usuário e senha na mesma tela
await ir(`https://painel.${dominio}/`);
await page.type('#usuario', usuario);
await page.type('#senha', env.PAINEL_SENHA);
await print('painel-login');

await Promise.all([page.waitForNavigation({ waitUntil: 'networkidle0' }), page.click('#entrar')]);
await espera(1500);
await print('painel-home');

await ir(`https://painel.${dominio}/${usuario}/files/public_html/`);
await print('painel-public_html');

// Site do estagiário com a página de boas-vindas
await ir(`https://${usuario}.${dominio}/`);
await print('site-boas-vindas');

// Subdomínio sem estagiário
await ir(`https://ninguem-aqui.${dominio}/`);
await print('slot-vazio');

// phpMyAdmin com o usuário do estagiário
await ir(`https://db.${dominio}/`);
await page.type('#input_username', usuario);
await page.type('#input_password', env.BANCO_SENHA);
await Promise.all([page.waitForNavigation({ waitUntil: 'networkidle0' }), page.click('#input_go')]);
await espera(2000);
await print('phpmyadmin');

// Celular
await tamanho(400, 820);
await ir(`https://painel.${dominio}/`);
await print('celular-login');
await ir(`https://painel.${dominio}/${usuario}/files/`);
await print('celular-painel');

await browser.close();
