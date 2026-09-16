# TASK-002 — Tornar a infraestrutura da demonstração persistente e acessível na rede local

Estado: ativada. Nenhuma implementação iniciada ainda; worktree da task ainda não criada.

## Autorização humana

- Ordem explícita do usuário nesta sessão, em resposta à proposta do orquestrador de ativar a TASK-002: "então segue".
- Reafirmação: a TASK-001 foi encerrada e publicada antes desta ativação; a regra de uma task por vez foi respeitada.
- Escopo autorizado: somente a TASK-002. Não iniciar TASK-003 ou posterior nesta sessão.

## Base Git no momento da ativação

- `HEAD` = `origin/astra-main` = `d5510c704750e10cf0c9fbd2f3902d510686aae2` (commit de encerramento da TASK-001).
- `origin/main` intocada em `32f44e9bb0b68e5ded3c4fe6d93bbd0cbcd6652a`.
- Árvore limpa na ativação; nenhuma worktree de task existente.

## Escopo declarado

Spring com PostgreSQL persistente, migrações versionadas e configuração segura para notebook e celulares na rede local. Substitui a continuidade efêmera do H2 no cenário demonstrado. Sem hospedagem pública, sem infraestrutura paga, sem segredos versionados. A migração preserva leitores e escritores existentes.

Donos: `backend-java` implementa; `runner` prova operacionalmente; `qa-tests` confirma acesso em dispositivo quando habilitado; `code-reviewer` dá veredito independente antes de qualquer commit.

## Critérios de aceite e situação

1. Reinício do backend preserva dados de demonstração criados durante o ensaio — executável nesta sessão.
2. Androids na rede configurada alcançam a API do notebook — PENDENTE de B-002; depende de ação humana para validar rede, endereço do notebook e dispositivos disponíveis.
3. Nenhuma configuração de demonstração afirma disponibilidade quando o notebook está desligado — executável nesta sessão.

## Bloqueios

- B-002 permanece aberto e limita o critério 2 acima. O critério não será declarado satisfeito sem prova em dispositivo real; a ausência será registrada explicitamente, não silenciada.
- B-001 (Leroy) não afeta esta task.

## Worktree e implementação

- Worktree `/Users/arenas/OrcaRepos/AuraSmartHAS/worktrees/task-002-persistent-demo-infrastructure`, branch `task-002/persistent-demo-infrastructure`, criada de `astra-main` em `d5510c704750e10cf0c9fbd2f3902d510686aae2`.
- Entregue: `V1__baseline.sql` com as 12 entidades; Flyway ligado no perfil `postgres` com `ddl-auto: validate` e desligado no `dev`; `AURA_DB_PASSWORD` sem default; `server.address` explícito; CORS por padrão de origem em vez de curinga; 5432 publicada só em loopback; `.env` adicionado ao `.gitignore`; `backend-spring/.env.example` criado; README com o caminho PostgreSQL e o IP do notebook para os Androids.

## Entrega

- Commit na branch da task: `347bdac`. Squash-merge em `astra-main`: `0cc68ecd5aae0a9f31cd5b1ab02e073579b21616`, com `HEAD` e `origin/astra-main` confirmados nesse hash após o push.
- Mensagem literal: `feat(infra): persist demo data in postgresql with versioned schema`.
- `main` não foi tocada: `origin/main` permanece `32f44e9bb0b68e5ded3c4fe6d93bbd0cbcd6652a`.

## Evidência de execução

- Suíte H2: 72 testes, 0 falhas, 0 erros, exit 0 — `/tmp/aura-task-002-h2-final-20260915T215343.log`.
- PostgreSQL real com Testcontainers: 2 testes, 0 falhas, BUILD SUCCESS — `/tmp/aura-task-002-postgres-20260915T215304.log`.
- Boot 1 no perfil `postgres`: Flyway aplicou `V1`, seed populou — `/tmp/aura-task-002-boot1-20260915T214433.log`.
- Boot 2 após parada e nova subida: schema já em v1 sem reaplicar, dados preservados — `/tmp/aura-task-002-boot2-20260915T214820.log`.
- Critério 1 provado com dado real: medicamento `PROVA-REINICIO-TASK-002` criado via API durante o ensaio sobreviveu ao reinício; contagens idênticas antes e depois (products 105, users 3, homes 1, signals 97, medications 4).
- Critério 2 provado na rede: `http://192.168.1.28:8080/api/v1/health` respondeu 200; a porta 5432 não responde pelo IP da LAN.
- Critério 3: auditoria de `DEMO.md`, `RODAR-COM-DOCKER.md` e `README.md` não encontrou alegação de disponibilidade contínua; o README passou a declarar que a API existe apenas com o notebook ligado na rede local.

## Achados colaterais corrigidos

- `.env` não estava no `.gitignore`, num repositório que passaria a orientar a criação de `.env` com senha de banco. Corrigido com `!**/.env.example` para preservar os dois modelos já versionados.
- O CORS usava `setAllowedOrigins`, que só casa origem literal e recusaria as faixas de rede local. Trocado por `setAllowedOriginPatterns`.
- A porta 5432 estava publicada em todas as interfaces.

## Desvios de protocolo registrados

- A implementação foi feita pelo orquestrador, não por `backend-java`: os agentes despachados travavam sem escrever, e encerrá-los por `TaskStop` ou `tmux kill-pane` derrubava a sessão principal do usuário.
- A revisão independente do diff foi feita pelo usuário, conforme D-009, e não por agente `code-reviewer`.
- Ambiente: não havia JDK na máquina; OpenJDK 21 foi instalado pela fórmula do Homebrew sob autorização expressa do usuário.

## Próximo passo

- Commit, squash-merge em `astra-main` e push; depois `- [X]` no roadmap e commit de encerramento de memória.
- Em seguida, e fora desta task, a página de parceiro e o catálogo multi-fornecedor (D-008), que é o único bloco do roteiro do vídeo que ainda não existe no código.

## Entrada para a próxima task documental

Pedidos registrados na 3ª Mentoria e na reunião interna, a serem refletidos no roadmap: marketplace multi-fornecedor com página de parceiro e redirecionamento ao Leroy Merlin Empresas; remoção da logística; correção do dado de centro de distribuição para loja-como-CD, com Cajamar como único CD; nomenclatura humana nas três superfícies, estendendo o commit `19dc1bb`; validação real com dois idosos; base de dados real também na nossa parte; e evidência explícita da AI Logistics Extension na demonstração.
