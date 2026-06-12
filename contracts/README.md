# contracts

Single source of truth for the two mini_vpn client contracts.

- `backend-api.openapi.yaml` — ② App ↔ cloud control plane (OpenAPI 3.1).
- `local-control.schema.json` — ① GUI ↔ local core messages (JSON Schema 2020-12, semantics only).
- `mock/*.json` — ② response fixtures the macOS app reads.
- `mock/local-control/*.json` — ① sample messages.

## Validate

```bash
cd contracts
npm install
npm run validate
```

`validate` runs: OpenAPI lint (redocly) + inline-example conformance
(openapi-examples-validator) + mock conformance (ajv) + local-control
conformance (ajv). The backend and the macOS app are both expected to
conform to these files — the contract is the cross-layer consistency boundary.

Payment flows are intentionally not implemented (501 stubs).
