# ADR 0002: Ciclo de cuidado local e parceiro comercial transparente

- **Data:** 2026-09-14
- **Status:** Aceito para planejamento; execução depende de ativação de tasks

## Contexto

O Aura usa Flutter para idoso, React Native para familiar, Angular para operação e Spring como backend. A demonstração é local, não há credenciais Leroy e o FastAPI é legado.

## Decisão

Priorizar Flutter → Spring → React Native → confirmação no Flutter, com PostgreSQL persistente, outbox, FCM e client tools ElevenLabs na LAN. Tratar Leroy como catálogo curado com link oficial e pedido acadêmico identificado. FastAPI não participa do caminho ativo salvo task explícita.

## Consequências

O produto demonstra comunicação e ação concluída sem alegar compra, estoque, preço, entrega real ou rastreio. A integração comercial futura depende de autorização. Voz não impede o uso por texto e o sistema não mostra sucesso falso sob falha.

## Alternativas descartadas

Depender de API Leroy inexistente, usar FastAPI como segunda fonte de verdade, guardar eventos apenas nos clientes e tratar evento enviado como ajuda humana confirmada.
