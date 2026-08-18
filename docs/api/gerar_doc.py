#!/usr/bin/env python3
"""Gera uma página de documentação da API a partir do openapi.json exportado.

Uso: python3 docs/api/gerar_doc.py docs/api/openapi.json docs/api/aura-api.html
O Redoc/Swagger continuam disponíveis; esta versão prioriza leitura rápida:
uma operação por card, agrupadas por contexto, com exemplo e erros à vista.
"""
import html
import json
import sys

CORES = {"get": "#58a6ff", "post": "#3fb950", "put": "#f0883e", "delete": "#f85149", "patch": "#a371f7"}


def exemplo_do_schema(schema, spec, profundidade=0):
    """Monta um exemplo a partir do schema, seguindo $ref e usando os examples declarados."""
    if not schema or profundidade > 6:
        return None
    if "$ref" in schema:
        nome = schema["$ref"].split("/")[-1]
        return exemplo_do_schema(spec["components"]["schemas"].get(nome, {}), spec, profundidade + 1)
    if "example" in schema:
        return schema["example"]
    tipo = schema.get("type")
    if tipo == "object" or "properties" in schema:
        return {k: exemplo_do_schema(v, spec, profundidade + 1) for k, v in schema.get("properties", {}).items()}
    if tipo == "array":
        item = exemplo_do_schema(schema.get("items", {}), spec, profundidade + 1)
        return [item] if item is not None else []
    if schema.get("enum"):
        return schema["enum"][0]
    return {"string": "string", "integer": 0, "number": 0.0, "boolean": True}.get(tipo)


def conteudo_json(content):
    """springdoc usa '*/*' quando o controller não declara produces; aceita os dois."""
    return content.get("application/json") or content.get("*/*") or {}


def bloco_json(valor):
    if valor is None:
        return ""
    return html.escape(json.dumps(valor, indent=2, ensure_ascii=False))


def gerar(spec):
    info = spec["info"]
    grupos = {}
    for rota, item in spec["paths"].items():
        for metodo, op in item.items():
            if metodo not in CORES:
                continue
            grupo = (op.get("tags") or ["Outros"])[0]
            grupos.setdefault(grupo, []).append((rota, metodo, op))

    ordem = sorted(grupos, key=lambda g: g)
    partes = []

    for grupo in ordem:
        ops = sorted(grupos[grupo], key=lambda x: (x[0], x[1]))
        cards = []
        for rota, metodo, op in ops:
            cor = CORES[metodo]
            protegida = bool(op.get("security")) or "security" not in op
            admin = "admin" in (op.get("summary", "") + json.dumps(op.get("responses", {}))).lower() \
                and "hasRole" not in ""  # marcado manualmente abaixo
            admin = "/ops/" in rota or (metodo in ("post", "put", "delete") and "/catalog/" in rota)

            params = "".join(
                f'<li><code>{html.escape(p["name"])}</code>'
                f'<span class="tipo">{html.escape(p.get("schema", {}).get("type", "—"))}</span>'
                f'<span class="onde">{p["in"]}</span>'
                f'{" <span class=obrig>obrigatório</span>" if p.get("required") else ""}</li>'
                for p in op.get("parameters", []))

            corpo = ""
            rb = conteudo_json(op.get("requestBody", {}).get("content", {}))
            if rb:
                ex = exemplo_do_schema(rb.get("schema", {}), spec)
                if ex is not None:
                    corpo = f'<div class="bloco"><span class="rotulo">corpo da requisição</span><pre>{bloco_json(ex)}</pre></div>'

            sucesso, erros = "", []
            for codigo, resp in sorted(op.get("responses", {}).items()):
                desc = html.escape(resp.get("description", ""))
                conteudo = conteudo_json(resp.get("content", {}))
                if codigo.startswith("2"):
                    ex = exemplo_do_schema(conteudo.get("schema", {}), spec)
                    corpo_ex = f"<pre>{bloco_json(ex)}</pre>" if ex is not None else ""
                    sucesso = (f'<div class="bloco"><span class="rotulo ok">{codigo} · resposta</span>{corpo_ex}</div>')
                else:
                    exemplos = conteudo.get("examples", {})
                    code = next(iter(exemplos), "")
                    erros.append(f'<li><span class="cod">{codigo}</span>'
                                 f'<code class="erro">{html.escape(code)}</code>'
                                 f'<span class="desc">{desc}</span></li>')

            cards.append(f'''
      <article class="op" data-busca="{html.escape((metodo + " " + rota + " " + op.get("summary", "")).lower())}">
        <header>
          <span class="metodo" style="background:{cor}22;color:{cor};border-color:{cor}55">{metodo.upper()}</span>
          <code class="rota">{html.escape(rota)}</code>
          {'<span class="selo admin">admin</span>' if admin else ('<span class="selo">JWT</span>' if protegida else '<span class="selo publica">pública</span>')}
        </header>
        <p class="resumo">{html.escape(op.get("summary", ""))}</p>
        {f'<div class="bloco"><span class="rotulo">parâmetros</span><ul class="params">{params}</ul></div>' if params else ''}
        {corpo}
        {sucesso}
        {f'<div class="bloco"><span class="rotulo">erros possíveis</span><ul class="erros">{"".join(erros)}</ul></div>' if erros else ''}
      </article>''')

        partes.append(f'''
    <section class="grupo" id="{html.escape(grupo.replace(" ", "-").replace(".", ""))}">
      <h2>{html.escape(grupo)}</h2>
      {"".join(cards)}
    </section>''')

    menu = "".join(
        f'<a href="#{html.escape(g.replace(" ", "-").replace(".", ""))}">{html.escape(g)}'
        f'<span class="cont">{len(grupos[g])}</span></a>' for g in ordem)

    total = sum(len(v) for v in grupos.values())

    return f'''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(info["title"])} — referência</title>
<style>
  :root {{ color-scheme: dark; --bg:#0d1117; --surface:#161b22; --surface2:#1c2430; --border:#21262d;
           --text:#c9d1d9; --strong:#f0f6fc; --muted:#8b949e; --accent:#f0883e; --info:#58a6ff;
           --danger:#f85149; --ok:#3fb950; }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--text); font-size:15px; line-height:1.55;
          font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; }}
  code, pre {{ font-family:ui-monospace,SFMono-Regular,Menlo,monospace; }}
  .topo {{ position:sticky; top:0; z-index:5; background:rgba(13,17,23,.94); backdrop-filter:blur(8px);
           border-bottom:1px solid var(--border); padding:16px 28px; }}
  .topo h1 {{ margin:0; font-size:20px; color:var(--strong); }}
  .topo p {{ margin:2px 0 0; color:var(--muted); font-size:13px; }}
  .busca {{ margin-top:12px; width:100%; max-width:460px; padding:9px 14px; border-radius:9px;
            border:1px solid var(--border); background:var(--bg); color:var(--text); font-size:14px; }}
  .busca:focus {{ outline:2px solid var(--info); }}
  .layout {{ display:flex; gap:32px; max-width:1180px; margin:0 auto; padding:28px; align-items:flex-start; }}
  nav {{ position:sticky; top:130px; width:210px; flex:none; display:flex; flex-direction:column; gap:2px; }}
  nav a {{ color:var(--text); text-decoration:none; font-size:13px; padding:7px 10px; border-radius:7px;
           display:flex; justify-content:space-between; gap:8px; }}
  nav a:hover {{ background:var(--surface2); color:var(--strong); }}
  nav .cont {{ color:var(--muted); font-size:11px; }}
  main {{ flex:1; min-width:0; }}
  h2 {{ font-size:17px; color:var(--strong); margin:28px 0 12px; padding-bottom:7px;
        border-bottom:2px solid var(--accent); }}
  .grupo:first-child h2 {{ margin-top:0; }}
  .op {{ background:var(--surface); border:1px solid var(--border); border-radius:11px;
         padding:16px 18px; margin-bottom:12px; }}
  .op header {{ display:flex; align-items:center; gap:10px; flex-wrap:wrap; }}
  .metodo {{ font-size:11px; font-weight:700; padding:3px 9px; border-radius:6px; border:1px solid; letter-spacing:.04em; }}
  .rota {{ color:var(--strong); font-size:13.5px; }}
  .selo {{ margin-left:auto; font-size:10px; text-transform:uppercase; letter-spacing:.06em;
           color:var(--muted); border:1px solid var(--border); border-radius:999px; padding:2px 8px; }}
  .selo.admin {{ color:var(--accent); border-color:#f0883e55; }}
  .selo.publica {{ color:var(--ok); border-color:#3fb95055; }}
  .resumo {{ margin:8px 0 0; font-size:14px; }}
  .bloco {{ margin-top:12px; }}
  .rotulo {{ display:block; font-size:10px; text-transform:uppercase; letter-spacing:.07em;
             color:var(--muted); margin-bottom:5px; }}
  .rotulo.ok {{ color:var(--ok); }}
  pre {{ background:#0b0f14; border:1px solid var(--border); border-radius:8px; padding:11px 13px;
         font-size:12.5px; overflow-x:auto; margin:0; }}
  ul {{ margin:0; padding:0; list-style:none; }}
  .params li {{ font-size:13px; padding:3px 0; display:flex; gap:8px; align-items:baseline; flex-wrap:wrap; }}
  .params code {{ color:var(--info); }}
  .tipo, .onde {{ font-size:11px; color:var(--muted); }}
  .obrig {{ font-size:10px; color:var(--danger); text-transform:uppercase; }}
  .erros li {{ display:flex; gap:9px; align-items:baseline; font-size:12.5px; padding:3px 0; flex-wrap:wrap; }}
  .cod {{ color:var(--danger); font-weight:700; font-family:ui-monospace,monospace; min-width:30px; }}
  .erro {{ color:var(--accent); font-size:11.5px; }}
  .desc {{ color:var(--muted); }}
  .vazio {{ color:var(--muted); padding:40px 0; text-align:center; }}
  footer {{ border-top:1px solid var(--border); color:var(--muted); font-size:12px;
            padding:22px 28px; text-align:center; }}
  @media (max-width:880px) {{ nav {{ display:none; }} .layout {{ padding:18px; }} }}
</style>
</head>
<body>
<div class="topo">
  <h1>{html.escape(info["title"])} <span style="color:var(--muted);font-size:13px">v{html.escape(info.get("version",""))}</span></h1>
  <p>{total} operações · base <code>http://localhost:8080</code> · autenticação JWT (Bearer) ·
     contas de demonstração: <code>ana@aura.com</code> · <code>admin@aura.com</code> — senha <code>aura1234</code></p>
  <input class="busca" id="busca" type="search" placeholder="Filtrar por rota, método ou descrição…" autocomplete="off">
</div>
<div class="layout">
  <nav>{menu}</nav>
  <main>{"".join(partes)}<p class="vazio" id="vazio" hidden>Nenhuma rota encontrada.</p></main>
</div>
<footer>
  Gerado a partir de <code>openapi.json</code> · AURA Care-Chain · Smart HAS · FIAP 2026<br>
  Swagger interativo em <code>/swagger-ui.html</code> com o backend no ar.
</footer>
<script>
  const campo = document.getElementById('busca');
  const ops = [...document.querySelectorAll('.op')];
  const grupos = [...document.querySelectorAll('.grupo')];
  const vazio = document.getElementById('vazio');
  campo.addEventListener('input', () => {{
    const termo = campo.value.trim().toLowerCase();
    ops.forEach(op => {{ op.hidden = termo !== '' && !op.dataset.busca.includes(termo); }});
    grupos.forEach(g => {{ g.hidden = [...g.querySelectorAll('.op')].every(o => o.hidden); }});
    vazio.hidden = ops.some(o => !o.hidden);
  }});
</script>
</body>
</html>
'''


if __name__ == "__main__":
    entrada, saida = sys.argv[1], sys.argv[2]
    with open(entrada, encoding="utf-8") as f:
        spec = json.load(f)
    with open(saida, "w", encoding="utf-8") as f:
        f.write(gerar(spec))
    print(f"gerado: {saida}")
