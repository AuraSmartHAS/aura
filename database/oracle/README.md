# Banco Oracle do AURA (Fase 6)

O schema e o PL/SQL **moram no back-end**, versionados pelo Flyway em
`backend-spring/src/main/resources/db/migration/oracle/`. Esta pasta guarda o que fica fora da
aplicação: dados simulados, consultas de demonstração e o script único para quem quer instalar
sem subir o app.

| Arquivo | Para que serve |
|---|---|
| `dados/leituras-pulseira.csv` | 21 dias de leituras da pulseira (passos, FC de repouso, sono) de 3 casas simuladas |
| `dados/leituras-pulseira.ctl` | Arquivo de controle do **SQL*Loader** que importa o CSV para a tabela de preparo |
| `carga-simulada.sql` | 3 casas, familiares, medicações, 21 dias de doses, relatos e histórico de SOS |
| `importar-leituras.sql` | Preparo → leituras da pulseira em `SIGNALS`; roda `PRC_REGISTRAR_ALERTAS` em todas as casas |
| `consultas-demo.sql` | As functions dentro de `SELECT` e as procedures com `DBMS_OUTPUT` — o roteiro da demo |
| `carregar-dados.sh` | Os três passos da carga, dentro do container |
| `instalar-tudo.sql` | Schema + PL/SQL num arquivo só, gerado das migrations por `gerar-script-unico.sh` |

## Os três perfis de casa da carga

| Casa | Perfil | O que deve aparecer |
|---|---|---|
| Casa da Dona Lúcia | toma quase tudo no horário, rotina estável | adesão alta, nenhum aviso de rotina |
| Casa do Seu Jorge | esquece cerca de 4 em 10 doses e não tomou nada nas últimas 48 h | avisos de doses não tomadas e de adesão baixa |
| Casa da Dona Celina | passos da pulseira caem pela metade nos últimos 3 dias | aviso de mudança de rotina |

As datas são relativas ao dia em que a carga roda (fuso de São Paulo), e toda linha tem chave fixa:
rodar duas vezes não duplica.

## Caminho A — app + Oracle em container (o da demo)

```bash
export AURA_DB_PASSWORD='uma-senha-sua'
docker compose -f docker-compose.yml -f docker-compose.oracle.yml up --build -d
# espere o backend ficar saudável: o Flyway cria tabelas e PL/SQL, o seed cria contas e catálogo
./database/oracle/carregar-dados.sh
```

Conexão no SQL Developer: usuário `aura`, a senha acima, `localhost:1521`, serviço `FREEPDB1`.

## Caminho B — só o banco, por script (SQL Developer ou servidor da FIAP)

Abra `instalar-tudo.sql` no SQL Developer conectado ao seu usuário e rode como script (F5).
Depois rode `carga-simulada.sql`, importe o CSV (SQL*Loader ou o assistente de importação do
SQL Developer para a tabela `STG_LEITURA_PULSEIRA`) e rode `importar-leituras.sql`.

- O script **aborta sem tocar em nada** se o seu usuário já tiver uma tabela com nome do AURA
  (`USERS`, `HOMES`, `ORDERS`...). Ele nunca apaga tabela de outra disciplina.
- Sem o app, não há catálogo de produtos: as recomendações da carga são puladas, o resto entra.
- **Os caminhos não se misturam.** O app sobre um schema criado pelo script falha de propósito:
  o perfil oracle tem `baseline-on-migrate: false`, então o Flyway não "adota" tabelas que ele não criou.
- Tudo evita recurso exclusivo do 23ai/26ai (BOOLEAN em SQL, `IF NOT EXISTS`, `VALUES` com
  várias linhas, `SELECT` sem `FROM`): roda num 19c.
