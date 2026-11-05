# Roteiro do vídeo: Fase 7 (até 5 min, YouTube não listado)

O enunciado pede o app rodando. O caminho que mostra as duas partes de uma vez é: a Maria confirma
uma dose no app, a trigger grava o aviso no Oracle e o aviso aparece no painel da Ana.

## Antes de gravar

```bash
# 1. Ambiente limpo: o aviso de estoque é um por remédio por dia, e um ensaio no mesmo banco "gasta" o de hoje.
export AURA_DB_PASSWORD='uma-senha-sua'
docker compose -f docker-compose.yml -f docker-compose.oracle.yml down -v
docker compose -f docker-compose.yml -f docker-compose.oracle.yml up --build -d --wait oracle backend
./database/oracle/carregar-dados.sh

# 2. Painel da Ana (4200) e, se houver emulador, o app da Maria (Flutter, com BACKEND_BASE_URL apontando para a API)
cd web-admin && npm start

# 3. Levodopa da Maria a uma dose da linha: 3 doses/dia, 10 doses = 3,3 dias. A próxima confirmação cruza os 3 dias.
API=http://localhost:8080/api/v1
TOKEN=$(curl -s -H 'Content-Type: application/json' -d '{"email":"ana@aura.com","password":"aura1234"}' $API/auth/login | jq -r .token)
CASA=$(curl -s -H "Authorization: Bearer $TOKEN" $API/homes | jq -r '[.[]|select(.patientName=="Maria S.")][0].id')
MED=$(curl -s -H "Authorization: Bearer $TOKEN" $API/homes/$CASA/medications | jq -r '[.[]|select(.name|startswith("Levodopa"))][0].id')
curl -s -X PUT -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"stockDoses":10}' $API/medications/$MED
echo "Levodopa: $MED"
```

Abra as abas, nesta ordem:
1. slides (PDF);
2. painel `localhost:4200`, logado como `ana@aura.com`, na casa da Maria;
3. app da Maria;
4. Swagger `localhost:8080/swagger-ui.html`, autorizado com o token da Ana;
5. SQL Developer (ou `sqlplus`) com `database/oracle/consultas-demo.sql` aberto;
6. a página da última run verde de **Entrega contínua (Oracle)** no GitHub Actions.

Senha de todas as contas: `aura1234`.

Sem emulador, a dose pode ser confirmada pelo Swagger (`POST /medications/{id}/confirm`, com o id impresso
acima). É a mesma rota que o app chama.

## Roteiro

| Tempo | Tela | O que dizer e fazer |
|---|---|---|
| 0:00–0:25 | Slides 1 e 2 | Quem somos: nome e RM de cada um. O AURA em uma frase: cuidado em casa para idosos com Parkinson, com a família por perto. |
| 0:25–0:50 | Slide 3 | Na Fase 6 o banco passou a avisar; na Fase 7 ele fica organizado e chega sozinho à produção. Os números: 9 rotinas viram 5 packages, 2 triggers, 194 testes (64 contra Oracle real), 11 de 11 no smoke. |
| 0:50–1:20 | Slide 4 + SQL Developer | Os packages e o que cada um guarda. Rodar a conferência final de `consultas-demo.sql`: 5 packages e 2 triggers VALID, nenhuma function ou procedure solta. |
| 1:20–2:20 | **App rodando**: app da Maria + painel da Ana | Mostrar no painel os avisos da casa. No app da Maria, confirmar a dose da Levodopa (toque, ou "tomei a levodopa" por voz). Voltar ao painel e atualizar: aparece "Estoque acabando · Levodopa + Carbidopa: 9 doses, cobertura de 3,0 dias". Dizer: "ninguém chamou rota nova; a trigger viu o estoque cruzar a linha e gravou o aviso". Slide 6 para os quatro cuidados da trigger. |
| 2:20–2:50 | SQL Developer + slide 5 | Bloco 8: o UPDATE baixa a régua de adesão para 75% e devolve para 80%. Mostrar as duas linhas em `REGRA_ALERTA_HIST`, com antes, depois e programa. |
| 2:50–3:30 | Swagger + slide 7 | `GET /homes/{id}/consulta?entidade=signals&coluna=type&valor=SLEEP&limite=5` e `.../consulta/agrupada?entidade=alerta&coluna=regra` (aparece o `ESTOQUE_BAIXO` de agora há pouco). Em seguida `coluna=type = type OR 1=1 --`, que volta 400. Explicar as quatro defesas. |
| 3:30–4:30 | GitHub Actions + slide 8 | Os três jobs da run verde. Abrir o resumo: testes por classe, migrations, objetos PL/SQL VALID e a tabela do smoke. Mostrar os artefatos `relatorio-testes` e `logs-deploy`. |
| 4:30–5:00 | Slides 9 e 10 | Evidências e valor: a família é avisada quando o remédio começa a acabar; o time tem PL/SQL testado e deploy reproduzível. Agradecer. |

## Frases-âncora

- "As regras da Fase 6 não mudaram uma linha: mudaram de casa, para packages com contrato e corpo."
- "A dose vale mais que o aviso: se gravar o aviso falhar, a falha vai para o log e a dose fica."
- "O Dynamic SQL escolhe tabela e coluna na hora, mas só entre as que o dicionário de dados conhece; valor nunca entra como texto."
- "Cada push sobe um Oracle do zero, confere o PL/SQL por dentro, usa a API como o app usa e só então fica verde."

## Depois de publicar

1. Suba o vídeo como **não listado** e copie o link. Copie também o link da run verde no GitHub Actions.
2. Depois do commit da entrega, gere o ZIP. O comando troca os marcadores nos HTML, gera os PDFs e monta a pasta:
   ```bash
   docs/fase7/gerar-entrega.sh https://youtu.be/SEU_ID https://github.com/AuraSmartHAS/aura/actions/runs/NUMERO
   ```
3. Descompacte o ZIP numa pasta qualquer e abra os dois PDFs antes de subir no FIAP ON, como pede o enunciado.
