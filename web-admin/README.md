# 🅰️ AURA Care-Chain — Painel administrativo (Angular)

Interface web da **cuidadora** e da **Torre de Controle**, consumindo a mesma API REST
(Spring Boot, `../backend-spring`) que os apps Flutter e React Native.

| Item | Valor |
|---|---|
| Stack | Angular 20 (standalone components, signals) · TypeScript · CSS puro |
| Comunicação | `HttpClient` + interceptor funcional que injeta o JWT |
| Rotas | `/login` · `/home` (casa) · `/admin` (Torre de Controle) · `/parceiros` (catálogo e parceiros), com guard de sessão |

## ▶️ Como rodar

```bash
# 1. suba a API
cd ../backend-spring && ./mvnw spring-boot:run

# 2. suba o painel
npm install
npm start          # http://localhost:4200
```

Entre com `ana@aura.com` / `aura1234` (cuidadora) ou `admin@aura.com` / `aura1234`
(Torre de Controle — libera os KPIs e o CRUD do catálogo).

## 🖥️ O que cada tela faz

**`/home` — a casa do paciente**
- ficha da casa e **checklist de segurança** editável (`[(ngModel)]` em cada checkbox);
- **risco por dimensão** com barra, nível e a lista de fatores e pesos que explicam o número;
- **avisos da casa**, **reposição por consumo** (estoque, ritmo e prazo à vista, com aprovação humana) e **consumo do período**;
- **Care-Chain** ("O que a casa precisa"): recomendação com motivo visível e botão de aprovar ou recusar;
- **sinais recentes** em tabela.

A esteira de entrega (pedidos, linha do tempo, mapa) **não** está neste painel: saiu da interface na D-008. O pedido nasce na aprovação e avança pelo app React Native, com a conta da Operação.

**`/admin` — Torre de Controle**
- KPIs de cuidado: casas monitoradas, sinais captados e casas com risco alto (sem OTIF nem carteira de pedidos: a logística saiu na D-008);
- **indicadores por casa** consolidados dentro do banco (adesão à medicação e passos da pulseira), com o botão "Consolidar agora"; só aparecem quando o backend roda sobre Oracle;
- **CRUD do catálogo** de acessibilidade com formulário `[(ngModel)]` e confirmação de exclusão.

## 🔗 Recursos de Angular usados

| Recurso | Onde |
|---|---|
| Interpolação `{{ }}` | todos os templates |
| Property binding `[ ]` | `[disabled]`, `[value]`, `[style.width]`, `[class.kpi__value--good]` |
| Event binding `( )` | `(click)`, `(ngSubmit)`, `(change)` |
| Two-way `[( )]` | `[(ngModel)]` no login, no checklist e no formulário de produto |
| `*ngIf` / `*ngFor` | listas de escores, recomendações, pedidos, catálogo e estados vazios |
| Serviços + DI | `ApiService`, `AuthService` (`inject()`) |
| Guard e interceptor | `authGuard`, `authInterceptor` |
| Pipes | `date`, `currency: 'BRL'`, `json`, `keyvalue` |

A base da API fica em `src/app/core/api.service.ts` (`baseUrl`).
