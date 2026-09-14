# TASK-003 — Implementar cadastro, consentimento e vínculo familiar por QR

## Objetivo e escopo

Permitir que contas novas criem/aceitem vínculo doméstico com consentimento e QR/código de uso único com validade de 10 minutos. Donos: `backend-java`, `mobile-flutter` e `mobile-react-native`; cada um só altera sua fronteira.

## Dependências, contratos e migrações

Depende de `TASK-001` e `TASK-002`. Define contrato de convite, aceite, consulta de vínculo e revogação de aparelho; autoria e acesso são derivados do servidor. Criar migração apenas para estado de convite/consentimento necessário, com escritor e leitor implementados juntos.

## Aceite

- Duas contas novas pareiam sem seed/manual de banco.
- Convite expirado ou reutilizado falha de forma clara.
- Aceite informa quem compartilha e o que será compartilhado.
- Outra família não acessa registros por identificador conhecido.

## Verificação, QA, revisão e continuidade

Runner executa testes de API e builds solicitados; QA percorre os dois Androids. Revisor avalia autorização e privacidade antes de commits. Checkpoint registra contrato implantado, migração e cenário concluído; Done requer integração, push e encerramento de memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-003-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
