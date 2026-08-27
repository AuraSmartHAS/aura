# DEMO — AURA Care-Chain em 5 minutos

Roteiro para quem vai **mostrar** o projeto: professor, jurado do NEXT, ou alguém do time que não escreveu esta parte. Segue na ordem, do zero até o pedido instalado.

> **Pré-requisito que já derrubou a demo uma vez:** o backend é Java 21. Se `./mvnw` responder *"Unable to locate a Java Runtime"*, instale e exporte antes de tudo:
> ```bash
> brew install openjdk@21
> export JAVA_HOME=/opt/homebrew/opt/openjdk@21 && export PATH="$JAVA_HOME/bin:$PATH"
> ```
> Node 20+ para o painel e o app. Nada de Docker, nada de banco externo: o perfil de desenvolvimento sobe um H2 em memória já populado.

---

## 1. Subir (3 terminais, ~2 min)

```bash
# terminal 1 — API, porta 8080
cd backend-spring && ./mvnw spring-boot:run

# terminal 2 — painel da cuidadora e Torre de Controle, porta 4200
cd web-admin && npm install && npm start

# terminal 3 — app React Native no navegador, porta 8081
cd mobile-rn && npm install && npm run web
```

Conferir que subiu antes de chamar alguém para assistir:

```bash
curl -s http://localhost:8080/api/v1/health
curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"ana@aura.com","password":"aura1234"}'
```

**Contas de demonstração** — senha `aura1234` nas três:

| Conta | Papel | Serve para |
|---|---|---|
| `ana@aura.com` | cuidadora | o fluxo inteiro do cuidado (já com consentimento aceito e a casa da Maria) |
| `admin@aura.com` | administrador | Torre de Controle e catálogo |
| `maria@aura.com` | paciente | a superfície de voz |

---

## 2. O fio de ouro (o que mostrar, na ordem)

A história é sempre a mesma: **uma frase move o mundo físico.** Cinco cenas.

### Cena 1 — O risco existe e é explicável · painel, `localhost:4200`
Entre como `ana@aura.com`. Na tela da casa, **desmarque "Barra de apoio no banheiro"** e clique em recalcular.

O escore sobe para **alto (0,9)** e — o ponto que interessa — a tela mostra **os três fatores e os pesos** que produziram esse número.
> *"O AURA não diz 'risco alto' e pronto. Ele diz por quê, com os fatores e os pesos na tela. E esses pesos não estão escondidos no código: vivem num arquivo YAML versionado, que uma pessoa que não programa consegue auditar."*

### Cena 2 — A recomendação chega explicada
Gere a recomendação. Ela aparece com o item, o motivo e a norma técnica (NBR 9050) que a sustenta.
> *"Ninguém recebe 'compre isto'. Recebe 'recomendamos a barra porque houve um quase-tombo relatado e o banheiro não tem apoio'."*

### Cena 3 — A decisão é humana
A Ana **aprova**. Só depois disso nasce o pedido.
> *"Nenhum pedido nasce sem a aprovação da cuidadora — e isso é verificado por teste automatizado, não por promessa."*

### Cena 4 — Vira logística de verdade
Avance o pedido pelos estágios até **instalado** e abra a **Torre de Controle**: OTIF, lead time e SLA saem dos pedidos reais, não de um mock.
> *"A última milha do cuidado é logística. O fluxo não termina em 'entregue' — termina em 'instalado'."*

### Cena 5 — A mesma API, outro app · `localhost:8081`
Entre no app React Native com a mesma conta. O mesmo risco, a mesma recomendação, o mesmo pedido.
> *"Trocamos de stack no mobile sem reescrever o produto, porque o contrato é o ponto de encontro. Nenhuma rota nova foi criada para o app novo."*

### Fecho — a prova de engenharia
```bash
cd backend-spring && ./mvnw test    # 18 testes verdes
```
São 61 testes automatizados no projeto: 18 no backend, 17 no painel, 6 de ponta a ponta no navegador, 7 no app React Native e 13 no app Flutter.

---

## 3. As respostas que sempre perguntam

**"E se o aplicativo errar e a pessoa cair mesmo assim?"**
O AURA **nunca prescreve nem diagnostica** — é um guardrail técnico, não uma promessa: a API bloqueia texto prescritivo na saída e devolve erro. Ele reduz risco e encaminha ao médico; não substitui ninguém.

**"Quem entrega e instala?"**
Um parceiro logístico e uma rede credenciada de instaladores. O AURA **orquestra** — detecta o risco, explica, aciona e rastreia. A arquitetura é acoplável a qualquer operação de produto + instalação.

**"De onde vêm os dados, tem sensor na casa?"**
Não há nenhum sensor. Os dados vêm do que a pessoa conta por voz, do uso do aplicativo e de um wearable comum. É uma decisão de projeto: sensor dedicado custa caro e a conversa já é o melhor sensor que temos.

**"E a privacidade?"**
Dado de saúde é sensível pela LGPD, então o consentimento é específico e destacado, e o app não passa do gate sem ele. O parceiro que entrega recebe apenas o item, o endereço e a janela de entrega — **nunca o escore nem o motivo clínico**.

---

## 4. Se algo quebrar no meio

| Sintoma | O que fazer |
|---|---|
| `./mvnw` diz "Unable to locate a Java Runtime" | Exporte o `JAVA_HOME` do topo deste arquivo |
| "Port 8080 was already in use" | `lsof -nP -iTCP:8080 -sTCP:LISTEN` e encerre o processo antigo |
| O painel abre mas não loga | A API não está de pé: confira o terminal 1 e o `curl` de health |
| O mapa abre sem o mapa | Falta a `GOOGLE_MAPS_API_KEY` no `.env` (veja `mobile/.env.example`) |
| A demo de voz não conecta | É rede/serviço externo. **Use o vídeo gravado** — ele é o plano A, não o plano B |

**Regra de palco:** o vídeo gravado do caminho feliz é o plano A. Demonstração ao vivo de voz depende de wi-fi de terceiro e já custou caro uma vez.
