# 🅰️ AURA Care-Chain — Painel administrativo (Angular)

Interface web da **cuidadora** e da **Torre de Controle**, consumindo a mesma API REST
(Spring Boot, `../backend-spring`) que os apps Flutter e React Native.

| Item | Valor |
|---|---|
| Stack | Angular 20 (standalone components, signals) · TypeScript · CSS puro |
| Comunicação | `HttpClient` + interceptor funcional que injeta o JWT |
| Rotas | `/login` · `/home` (casa) · `/admin` (Torre de Controle), com guard de sessão |

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
- **Care-Chain**: recomendação com motivo visível e botão de aprovar;
- **pedidos** com linha do tempo (aprovado → separando → em rota → entregue → instalado) e SLA;
- **sinais recentes** em tabela.

**`/admin` — Torre de Controle**
- KPIs (OTIF, fill rate, lead time, pedidos abertos, casas, risco alto) com destaque quando batem a meta;
- pedidos por estágio;
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
