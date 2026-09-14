# Instruções canônicas

Leia primeiro [AGENTS.md](AGENTS.md) e [START-HERE.md](START-HERE.md). As regras de continuidade, memória e papéis vivem na raiz do repositório; este arquivo é apenas a ponte para Claude Code.

## Observação histórica

O esquema abaixo é uma referência legada de organização Android/Kotlin. Ele não define a stack atual nem substitui o contrato compartilhado e as tasks versionadas.

## Estrutura histórica

Directories organization
app/
 |-- commons/
 |   |-- theme/
 |   |-- database/
 |   |-- network/
 |-- features/
 |   |-- feature A/
 |   |   |-- data/
 |   |   |   |-- dto.kt
 |   |   |   |-- dao.kt
 |   |   |   |-- (remote|local) dataSources.kt
 |   |   |   |-- repositories.kt
 |   |   |-- domain/
 |   |   |   |-- interactor.kt
 |   |   |   |-- use cases.kt
 |   |   |   |-- models.kt
 |   |   |-- presentation/
 |   |   |   |-- view.kt
 |   |   |   |-- viewModel.kt
 |   |   |   |-- viewData.kt
 |   |   |   |-- adapters.kt
