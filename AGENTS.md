# Protocolo de continuidade do Aura

> **STOP — somente bootstrap está autorizado agora.** Não iniciar `TASK-001` ou posterior porque está no roadmap. Uma ordem humana explícita ativa a task; se a preocupação já tiver sido esclarecida e o humano reafirmar o pedido, registre a decisão e execute o escopo completo.

## Retomada de uma sessão

Resolva primeiro o checkout canônico: leia `git worktree list --porcelain`, localize exatamente uma entrada `branch refs/heads/astra-main` e use seu `worktree <path>` como raiz de memória. Se a entrada estiver ausente ou houver mais de uma, escale; não adivinhe. Nesse checkout, leia nesta ordem: `ROADMAP.md`, este arquivo, `BLOCKERS.md`, as entradas recentes de `DECISIONS.md`, o checkpoint da única task `[-]` e o histórico Git real. Declare o estado encontrado e qualquer divergência antes de propor trabalho.

Use UTF-8, paths relativos à raiz e nomes de arquivos ASCII com hífen. Descubra a raiz com `git rev-parse --show-toplevel`; não dependa do diretório de uma conversa projectless.

## Papéis e fronteiras

| Papel | Modelo preferido | Única responsabilidade |
|---|---|---|
| `web-frontend` | Terra / Sonnet | Implementar Angular administrativo/operação. |
| `mobile-react-native` | Terra / Sonnet | Implementar aplicativo familiar React Native. |
| `mobile-flutter` | Terra / Sonnet | Implementar aplicativo idoso Flutter. |
| `backend-java` | Terra / Sonnet | Implementar Spring Boot. |
| `backend-python` | Terra / Sonnet | Trabalhar no FastAPI legado somente quando a task o pedir. |
| `qa-tests` | Terra / Sonnet | Planejar e executar QA manual via runner, inclusive Samsung quando disponível. |
| `code-reviewer` | Sol / Opus | Revisar diffs, sem codar, testar, commitar ou decidir produto. |
| `analista` | Sol / Opus | Investigar código e devolver evidências, sem alterar nada. |
| `runner` | Terra / Sonnet | Executar suites, builds e servidores; único escritor de checkpoints. |
| `vcs` | Terra / Sonnet | Operações Git mutantes, com a mensagem literal enviada pelo orquestrador. |

Os nomes canônicos com hífen mapeiam para estes nomes Codex com sublinhado: `web-frontend` → `web_frontend`, `mobile-react-native` → `mobile_react_native`, `mobile-flutter` → `mobile_flutter`, `backend-java` → `backend_java`, `backend-python` → `backend_python`, `qa-tests` → `qa_tests`, `code-reviewer` → `code_reviewer`; `analista`, `runner` e `vcs` mantêm o mesmo nome. Claude usa os nomes canônicos com hífen nos arquivos de agente.

Implementadores podem comunicar-se diretamente somente com `analista` e `runner`; estes respondem. Isso exige que a harness materialize os alvos da equipe. Se não os materializar, o orquestrador faz relay; ninguém inventa um canal. Toda a comunicação restante passa pelo orquestrador. Use agentes novos por task; revisor e analista não recebem contexto herdado e não são reutilizados após a task. Interromper não equivale a encerrar: interrompa, encerre processos iniciados pelo runner, marque o agente aposentado e use fechamento da harness quando existir.

## Ciclo de uma task

1. O `vcs` atualiza a base e cria `task-<id>/<slug>` de `astra-main` em worktree.
2. O orquestrador despacha apenas os donos do escopo declarado.
3. O implementador conclui um bloco coerente; o runner prova sua execução com saída primária, código de saída, marcador de log e horário quando cabível. `qa-tests` usa o runner para comandos e o Samsung quando previsto.
4. O revisor independente devolve veredito sobre aquele bloco/diff antes de qualquer commit. Achado bloqueante volta ao implementador; ninguém se autorrevisa.
5. Só então o `vcs` pode criar o commit solicitado literalmente. Commits aprovados podem compor o diff cumulativo; uma revisão final continua obrigatória antes do squash.
6. O `vcs` faz o squash-merge em `astra-main`, com mensagem única fornecida pelo orquestrador, e confirma o push. O primeiro push autorizado dessa branch usa `git push -u origin astra-main` para estabelecer upstream; pushes posteriores continuam sujeitos ao protocolo e à autorização.
7. Após squash/push verificados, o runner registra o hash de entrega, evidências e `- [X]` no roadmap canônico. O `vcs` cria o commit curto de encerramento somente de memória, também revisado, e faz push; só então esse Done é durável.
8. Depois de merge e push verificados, o `vcs` remove a worktree e a branch da task.

`TASK-000` é exceção autorizada: bootstrap, revisão, commit local e reconciliação bastam; não há push neste bootstrap.

## Memória canônica e um escritor

O checkout de `astra-main`, resolvido pela entrada única `branch refs/heads/astra-main` em `git worktree list --porcelain`, é a memória canônica. Exatamente uma task pode estar `[-]`; a sessão nova retoma somente essa task. Antes de despachar, o runner, por instrução exata do orquestrador, muda uma única entrada do roadmap para `[-]` e registra a autorização/reafirmação humana e o prompt/escopo no checkpoint canônico. Nenhuma outra entrada pode estar `[-]`; TODO nunca autoriza execução. Worktrees de task não alteram documentos globais ou `journal/`.

O `runner` é o único escritor de `journal/TASK-NNN-CHECKPOINT.md` e dos estados de runtime em `ROADMAP.md`, sempre por instrução exata do orquestrador. Durante o bootstrap, o redator documental escreve os arquivos globais. Depois dele, alterações estruturais de roadmap, decisões, ADRs e contexto exigem uma task documental dedicada; runner não toma nem redige essas decisões. Cópias materializadas/versionadas em worktrees de task são snapshots não canônicos, nunca lidos nem alterados; somente `journal/` no checkout único de `astra-main` é canônico.

O checkpoint é breve e frequente: estado confirmado, evidência, arquivos afetados, próximo passo e bloqueio. Se a interrupção ocorrer antes da revisão, mudanças não commitadas permanecem na worktree, mas seu estado fica no checkpoint; não existem commits WIP ou snapshots fora do protocolo. O checkpoint registra o hash do commit de entrega, jamais precisa registrar o hash do commit de memória que o contém.

Com memória canônica suja, o `vcs` preserva os bytes, integra somente código no worktree e prepara o encerramento no checkout canônico. Nunca faça stash, clean, reset ou sobrescrita implícita para “destravar” a integração; conflito exige escalonamento.

## Decisão, verificação e escalonamento

Escalone quando a solução envolver produto, privacidade, custo, arquitetura, exposição/remoção de dado, ou enfraquecimento de garantia. Não contorne um contrato frouxando o lado que falha: confira escritor, banco e leitor. `DECISIONS.md` é append-only; uma reversão cria nova entrada.

O orquestrador pode conferir evidência primária em modo somente leitura (saída, exit code, log, timestamp e hash de diff) quando a ferramenta não permitir prova pelo subagente. Ele nunca revisa qualquer diff nem substitui o revisor, e nunca escreve, implementa, executa comandos operacionais ou faz Git mutante. Todo desvio do ciclo é registrado.

## Limites de produto atuais

O FastAPI é referência legada e nunca segunda fonte de verdade. Não fazer compra, estoque, preço ou rastreio Leroy parecer integrado sem acesso autorizado. O trabalho ativo priorizará Flutter → Spring → React Native → retorno ao idoso, em dois Androids e notebook na rede local, mas somente após ativação humana de tasks.

## Configuração portável de agentes

As definições canônicas estão em `.agents/roles/`; adaptadores ficam em `.codex/agents/*.toml` e `.claude/agents/*.md`. A configuração foi verificada em 2026-09-14 contra a documentação de [subagentes Codex](https://learn.chatgpt.com/docs/agent-configuration/subagents), [subagentes Claude Code](https://code.claude.com/docs/en/subagents) e [modelos Claude](https://platform.claude.com/docs/en/models/overview). Os IDs indicam preferência, não disponibilidade garantida na conta; nunca subir automaticamente para modelo mais caro quando indisponível.

Arquivos de agente não atualizam agentes já materializados: reinicie a sessão e confirme a descoberta por `/agents` quando suportado. Em Codex, o runner pode validar estrutura com `codex doctor --summary --no-color --ascii`. Claude Code local pode exigir Node 24 no PATH; Node 18 causa `TypeError`. Não instalar ou alterar Node para contornar isso sem ordem humana. A versão local pode não validar arquivos individuais; o runtime deve enviar modelo e prompt explicitamente quando não carregar configuração de arquivo.
