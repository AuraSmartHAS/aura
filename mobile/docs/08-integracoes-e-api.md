# 08 · Integrações e API consumida

## Pacotes
`flutter_bloc` (estado) · `go_router` (navegação) · `get_it` (DI) · `dio` (REST) · `google_maps_flutter`+`geolocator` (mapas) · `firebase_core`+`firebase_messaging` (FCM) · `health` (wearable) · `supabase_flutter` (auth/realtime) · `shared_preferences` · voz (SDK ElevenLabs / `speech_to_text`).

## Endpoints consumidos (do backend — base em `BACKEND_BASE_URL`)
```
POST /signals                      # registrar sinal (voz/auto-relato/wearable)
POST /scores/recompute             # obter risco + explicação p/ exibir
GET  /homes/{id}/scores
GET  /catalog?riskTag=             # listar produtos
POST /recommendations              # criar recomendação
POST /recommendations/{id}/approve # cuidadora aprova (RN-022)
POST /orders/{id}/advance / GET /orders/{id}   # acompanhar pedido
GET  /ops/kpis /ops/orders /ops/alerts /ops/360   # Torre de Controle (Admin)
POST /notifications/register-token # registrar token FCM
```
Contrato completo: ver pacote do backend `07-api-contrato.md`.

## Mapas, push e wearable
- **Maps:** marcadores casa/nó/entrega/técnico + rota/ETA (vem do backend ou Distance Matrix).
- **FCM:** push de saúde (emergência/medicamento) e de status logístico; deep link abre a tela certa.
- **Wearable (`health`):** permissão (opt-in) → ler passos/FC/sono → enviar como `signal type=vitals source=wearable`.
