# backend

The ② control-plane API (Go + chi + sqlc + Postgres), isolated from the Rust core.
Conforms to `../contracts/backend-api.openapi.yaml` (OpenAPI 3.1) — the contract is the consistency boundary.

## Run

```bash
cp .env.example .env   # edit DATABASE_URL / JWT_SECRET
docker run -d --name mini-vpn-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=mini_vpn -p 5432:5432 postgres:16-alpine
go run ./cmd/server     # migrates on boot, listens on :$PORT (default 8080)
go run ./cmd/seed       # optional: idempotently seed a few shared dev nodes
```

## Interactive API docs (Scalar)

With the server running, open <http://localhost:8080/docs> for an interactive
Scalar API reference. Click **Authorize**, paste an `access_token` from
`POST /auth/register` or `/auth/login`, then call the protected endpoints — requests
hit the live server (same origin). The page serves the live contract from
`../contracts/backend-api.openapi.yaml`. Disable with `ENABLE_DOCS=false`
(override the spec location with `OPENAPI_SPEC_PATH`).

## Test

```bash
go test ./...   # integration tests spin up an ephemeral Postgres via dockertest; they SKIP if Docker is absent
```

`contract_test.go` validates live responses (register / subscription / nodes) against the OpenAPI doc. Payment endpoints are 501 stubs.

## Regenerate queries after editing SQL

```bash
sqlc generate
```
