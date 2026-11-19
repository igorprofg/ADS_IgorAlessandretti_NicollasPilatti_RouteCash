# Webhook Asaas - Etapa 1

Copie os arquivos para `src/webhooks/`.

No `.env`, adicione:

```env
ASAAS_WEBHOOK_TOKEN=<token com pelo menos 32 caracteres>
```

Para gerar um token forte:

```powershell
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

No `src/app.module.ts`, adicione:

```ts
import { WebhooksModule } from './webhooks/webhooks.module';
```

E inclua `WebhooksModule` no array `imports`.

Depois rode:

```powershell
npm run start:dev
```

Teste:

`POST http://localhost:3000/webhooks/asaas`

Header:

`asaas-access-token: <mesmo valor de ASAAS_WEBHOOK_TOKEN>`

Body:

```json
{
  "id": "evt_routecash_teste_001",
  "event": "CHECKOUT_PAID",
  "dateCreated": "2026-11-19 14:00:00",
  "checkout": {
    "id": "92ac29a0-9772-48ff-a00f-ffb09a27dfbf",
    "status": "PAID"
  }
}
```

Primeiro envio: `duplicado = false`.

Segundo envio do mesmo body: `duplicado = true`.
