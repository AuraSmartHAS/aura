#!/usr/bin/env python3
"""Importa produtos do produtos-leroy.csv para o catálogo da API.

Curadoria manual do site público — nunca scraping. Preencha o CSV (as duas linhas
EXEMPLO-* são só modelo: apague-as ou troque pelos produtos reais) e rode com o
backend de pé:

    python3 importar-catalogo.py                # valida e importa
    python3 importar-catalogo.py --dry-run      # só valida, não toca na API

Colunas: sku, name, category, price, installable (true/false), normRef,
riskTag, stockNearby. riskTags que o painel conhece: fall_bathroom, night_trips,
mobility, cognition, environment (e med_replenishment na linha do burn rate) —
outro valor funciona, mas aparece cru na tela.

SKU novo entra por POST; SKU que já existe é atualizado por PUT (mesma regra do
painel). Login padrão: admin@aura.com / aura1234 em http://localhost:8080 —
ajuste via AURA_API_URL, AURA_ADMIN_EMAIL e AURA_ADMIN_PASSWORD se precisar.
Lembrete de demo: o H2 é em memória — reiniciou o backend, importe de novo.
"""

from __future__ import annotations

import csv
import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("AURA_API_URL", "http://localhost:8080/api/v1")
EMAIL = os.environ.get("AURA_ADMIN_EMAIL", "admin@aura.com")
PASSWORD = os.environ.get("AURA_ADMIN_PASSWORD", "aura1234")
CSV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "produtos-leroy.csv")
KNOWN_TAGS = {"fall_bathroom", "night_trips", "mobility", "cognition", "environment", "med_replenishment"}


def request(method: str, path: str, body: dict | None = None, token: str | None = None):
    req = urllib.request.Request(f"{BASE}{path}", method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(req, data=data, timeout=15) as res:
        return json.loads(res.read() or b"null")


def load_rows() -> list[dict]:
    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        sys.exit("CSV vazio — preencha o produtos-leroy.csv antes de importar.")

    ok, problems = [], []
    for i, row in enumerate(rows, start=2):  # linha 1 é o cabeçalho
        sku = (row.get("sku") or "").strip()
        try:
            item = {
                "name": (row["name"] or "").strip(),
                "category": (row["category"] or "").strip(),
                "price": round(float(str(row["price"]).replace(",", ".")), 2),
                "installable": str(row["installable"]).strip().lower() in {"true", "sim", "1"},
                "normRef": (row.get("normRef") or "").strip() or None,
                "riskTag": (row.get("riskTag") or "").strip() or None,
                "stockNearby": int(row["stockNearby"]),
            }
        except (KeyError, TypeError, ValueError) as err:
            problems.append(f"linha {i} ({sku or 'sem sku'}): {err}")
            continue
        if not sku or not item["name"] or not item["category"]:
            problems.append(f"linha {i}: sku, name e category são obrigatórios")
            continue
        if item["price"] < 0 or item["stockNearby"] < 0:
            problems.append(f"linha {i} ({sku}): preço e estoque não podem ser negativos")
            continue
        if sku.startswith("EXEMPLO-"):
            print(f"  ~ pulando {sku} (linha-modelo — troque pelos produtos reais)")
            continue
        if item["riskTag"] and item["riskTag"] not in KNOWN_TAGS:
            print(f"  ! aviso: riskTag '{item['riskTag']}' ({sku}) não tem rótulo no painel — sai cru na tela")
        ok.append({"sku": sku, **item})

    if problems:
        sys.exit("CSV com problemas — nada foi importado:\n  - " + "\n  - ".join(problems))
    if not ok:
        sys.exit("Só sobraram as linhas-modelo EXEMPLO-* — preencha os produtos reais.")
    return ok


def main() -> None:
    rows = load_rows()
    if "--dry-run" in sys.argv:
        for r in rows:
            print(f"  ✓ {r['sku']} · {r['name']} · R$ {r['price']:.2f} · estoque {r['stockNearby']}")
        print(f"Validação ok: {len(rows)} produto(s) prontos. Rode sem --dry-run para importar.")
        return

    token = request("POST", "/auth/login", {"email": EMAIL, "password": PASSWORD})["token"]
    existentes = {p["sku"] for p in request("GET", "/catalog", token=token)}

    novos = atualizados = 0
    for r in rows:
        sku = r.pop("sku")
        if sku in existentes:
            request("PUT", f"/catalog/{sku}", r, token)
            atualizados += 1
            print(f"  ↻ atualizado {sku} · {r['name']}")
        else:
            request("POST", f"/catalog/{sku}", r, token)
            novos += 1
            print(f"  + criado    {sku} · {r['name']}")
    print(f"Pronto: {novos} criado(s), {atualizados} atualizado(s). Confira na Torre em /admin.")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.URLError as err:
        sys.exit(f"API fora do ar ou recusou ({err}). O backend está de pé em {BASE}?")
