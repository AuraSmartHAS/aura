# 00 · Visão de produto e premissas

## Personas
- **Maria (paciente, ~74):** usa o **mobile por voz**. Limitações motoras/cognitivas. Voice-first, tipografia gigante, alto contraste.
- **Ana (cuidadora):** usa o **mobile dashboard** (e o **portal web**). Aprova recomendações, acompanha pedidos.
- **Operador/Coordenação (Admin):** usa a **web (Torre de Controle)** — KPIs, fila logística, alertas.

## Inovação
"**Adaptação Preditiva como Serviço**": o app capta sinais de risco (quase-queda, mobilidade, etc.) e dispara a cadeia logística (recomendação → pedido → entrega → instalação) **antes do acidente**. Prevenção vira produto.

## Premissas (constraints de implementação)
- 100% entregável por um time de 5 pessoas. Sem IoT/hardware. Logística simulada.
- Leroy = mentora (não integra). Impacto social: prevenir queda (principal causa de internação por trauma na 3ª idade).
- Stack decidida: Flutter (mobile+web) · Backend Supabase-first + Python (escore) · PostgreSQL.

## Fluxo-herói (a jornada que tudo serve)
`voz (Maria relata quase-queda) → sinal → escore explicável (ALTO) → recomendação (barra NBR 9050) → Ana aprova → pedido → entrega no mapa → instalação → KPIs na Torre de Controle`.
