# Contracts Subsystem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the single source of truth for the two API contracts — `backend-api.openapi.yaml` (② App↔cloud) and `local-control.schema.json` (① GUI↔core) — plus mock fixtures, all machine-validated, so the backend and macOS app can be built in parallel against a frozen contract.

**Architecture:** A standalone `contracts/` tree validated by a small Node toolchain. The OpenAPI doc carries component schemas + inline response examples; mock `*.json` files (the fixtures the macOS app reads) are validated against those same schemas by an ajv script. The local-control schema is plain JSON Schema 2020-12 with sample messages validated the same way. "Tests" here = validators that must pass; each domain is added test-first (add a mock that fails validation → add the schema → validation passes).

**Tech Stack:** OpenAPI 3.1, JSON Schema 2020-12, Node 20+, `@redocly/cli` (OpenAPI lint), `openapi-examples-validator` (inline-example conformance), `ajv`/`ajv-formats` + `@apidevtools/json-schema-ref-parser` + `yaml` (mock + schema validation script).

**Constraints:** All artifacts land in the `mini_vpn_app` repo. The `mini_vpn` core repo is never touched. Run every command from the repo root `/Users/liushan/Documents/Personal/Languages/Rust/mini_vpn_app`.

---

## File Structure

| File | Responsibility |
|---|---|
| `contracts/package.json` | Node toolchain + `validate` npm scripts |
| `contracts/.gitignore` | ignore `node_modules` |
| `contracts/backend-api.openapi.yaml` | ② contract: auth, subscription, devices, nodes, purchase stubs |
| `contracts/local-control.schema.json` | ① contract: command/event message union (semantics only) |
| `contracts/scripts/validate-mocks.mjs` | validate `mock/*.json` against ② component schemas |
| `contracts/scripts/validate-local-control.mjs` | validate `mock/local-control/*.json` against ① schema |
| `contracts/mock/*.json` | ② response fixtures the macOS app reads |
| `contracts/mock/local-control/*.json` | ① sample messages |
| `contracts/README.md` | how to validate; what each file is |

**Schema/field freeze (used consistently across all tasks):**

- `User` = `{ id: uuid, email: email, created_at: date-time }`
- `TokenPair` = `{ access_token: string, refresh_token: string, token_type: "Bearer", expires_in: int(seconds) }`
- `Subscription` = `{ plan: enum[free,monthly,yearly], status: enum[active,expired], expires_at: date-time|null, device_limit: int }`
- `Device` = `{ id: uuid, name: string, platform: enum[macos,ios,android,windows], last_seen_at: date-time, created_at: date-time }`
- `Node` = `oneOf[SharedNode, DedicatedNode]` discriminated on `kind`
  - `SharedNode` = `{ id: uuid, kind:"shared", region, city, latency_ms: int, load: number(0..1), tier: enum[standard,premium] }`
  - `DedicatedNode` = `{ id: uuid, kind:"dedicated", region, city, label, static_ip: ipv4, expires_at: date-time, latency_ms: int, load: number(0..1) }`
- local-control command types: `connect{node_id}`, `disconnect`, `select_node{node_id}`, `auto`
- local-control event types: `state{state: enum[disconnected,connecting,connected,error]}`, `stats{up_bps,down_bps,up_bytes,down_bytes}`, `log{level: enum[debug,info,warn,error], message, ts}`

---

## Task 1: Node validation toolchain

**Files:**
- Create: `contracts/package.json`
- Create: `contracts/.gitignore`

- [ ] **Step 1: Create `contracts/.gitignore`**

```
node_modules/
```

- [ ] **Step 2: Create `contracts/package.json`**

```json
{
  "name": "mini-vpn-contracts",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "lint:api": "redocly lint backend-api.openapi.yaml",
    "validate:examples": "openapi-examples-validator backend-api.openapi.yaml",
    "validate:mocks": "node scripts/validate-mocks.mjs",
    "validate:local-control": "node scripts/validate-local-control.mjs",
    "validate": "npm run lint:api && npm run validate:examples && npm run validate:mocks && npm run validate:local-control"
  },
  "devDependencies": {
    "@apidevtools/json-schema-ref-parser": "^11.7.0",
    "@redocly/cli": "^1.25.0",
    "ajv": "^8.17.1",
    "ajv-formats": "^3.0.1",
    "openapi-examples-validator": "^5.0.0",
    "yaml": "^2.5.0"
  }
}
```

- [ ] **Step 3: Install dependencies**

Run: `cd contracts && npm install`
Expected: `node_modules/` created, no error. (`npm warn`s are fine.)

- [ ] **Step 4: Commit**

```bash
cd /Users/liushan/Documents/Personal/Languages/Rust/mini_vpn_app
git add contracts/package.json contracts/package-lock.json contracts/.gitignore
git commit -m "chore(contracts): node validation toolchain"
```

---

## Task 2: OpenAPI skeleton + mock validator script

This task stands up a minimal valid OpenAPI 3.1 doc (no business paths yet) and the mock validator, so later domain tasks are pure add-and-validate.

**Files:**
- Create: `contracts/backend-api.openapi.yaml`
- Create: `contracts/scripts/validate-mocks.mjs`

- [ ] **Step 1: Create the skeleton `contracts/backend-api.openapi.yaml`**

```yaml
openapi: 3.1.0
info:
  title: mini_vpn backend API
  version: 0.1.0
  description: >
    Control-plane API ② consumed by the client apps. Multi-user commercial
    service: email+password auth, time-based subscription, device binding,
    shared + dedicated-static-IP nodes. Payment flows are not implemented in
    this version (read-only status + 501 stubs only).
servers:
  - url: http://localhost:8080
    description: local dev
security:
  - bearerAuth: []
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
  schemas:
    Error:
      type: object
      required: [code, message]
      properties:
        code: { type: string }
        message: { type: string }
paths: {}
```

- [ ] **Step 2: Create `contracts/scripts/validate-mocks.mjs`**

```js
import RefParser from '@apidevtools/json-schema-ref-parser';
import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import YAML from 'yaml';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');

// mock file (under contracts/mock/) -> component schema name it must satisfy
const manifest = {
  // populated by later tasks, e.g. 'user.json': 'User'
};

const api = YAML.parse(readFileSync(resolve(root, 'backend-api.openapi.yaml'), 'utf8'));
const deref = await RefParser.dereference(api);
const schemas = deref.components?.schemas ?? {};

const ajv = new Ajv2020({ strict: false, allErrors: true });
addFormats(ajv);

let failed = 0;
for (const [file, schemaName] of Object.entries(manifest)) {
  const schema = schemas[schemaName];
  if (!schema) { console.error(`MISSING SCHEMA: ${schemaName} for ${file}`); failed++; continue; }
  const data = JSON.parse(readFileSync(resolve(root, 'mock', file), 'utf8'));
  const validate = ajv.compile(schema);
  if (validate(data)) { console.log(`ok   ${file} -> ${schemaName}`); }
  else { console.error(`FAIL ${file} -> ${schemaName}`); console.error(validate.errors); failed++; }
}
if (Object.keys(manifest).length === 0) console.log('(no mocks registered yet)');
process.exit(failed ? 1 : 0);
```

- [ ] **Step 3: Run the API lint and mock validator to verify the skeleton is valid**

Run: `cd contracts && npm run lint:api && npm run validate:mocks`
Expected: redocly reports no errors (warnings about no operations are acceptable); validate-mocks prints `(no mocks registered yet)` and exits 0.

- [ ] **Step 4: Commit**

```bash
cd /Users/liushan/Documents/Personal/Languages/Rust/mini_vpn_app
git add contracts/backend-api.openapi.yaml contracts/scripts/validate-mocks.mjs
git commit -m "feat(contracts): openapi 3.1 skeleton + mock validator"
```

---

## Task 3: Auth domain

**Files:**
- Create: `contracts/mock/user.json`
- Create: `contracts/mock/token-pair.json`
- Modify: `contracts/backend-api.openapi.yaml` (add schemas + auth paths)
- Modify: `contracts/scripts/validate-mocks.mjs` (register mocks)

- [ ] **Step 1: Create the mock fixtures (the failing "test")**

`contracts/mock/user.json`:
```json
{
  "id": "11111111-1111-4111-8111-111111111111",
  "email": "demo@example.com",
  "created_at": "2026-06-12T08:00:00Z"
}
```

`contracts/mock/token-pair.json`:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.demo.access",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.demo.refresh",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

- [ ] **Step 2: Register the mocks in `validate-mocks.mjs`**

Replace the `manifest` object with:
```js
const manifest = {
  'user.json': 'User',
  'token-pair.json': 'TokenPair',
};
```

- [ ] **Step 3: Run the validator to verify it FAILS (schemas missing)**

Run: `cd contracts && npm run validate:mocks`
Expected: FAIL with `MISSING SCHEMA: User for user.json` (exit 1).

- [ ] **Step 4: Add the auth schemas + paths to `backend-api.openapi.yaml`**

Under `components.schemas`, add:
```yaml
    User:
      type: object
      required: [id, email, created_at]
      properties:
        id: { type: string, format: uuid }
        email: { type: string, format: email }
        created_at: { type: string, format: date-time }
    TokenPair:
      type: object
      required: [access_token, refresh_token, token_type, expires_in]
      properties:
        access_token: { type: string }
        refresh_token: { type: string }
        token_type: { type: string, const: Bearer }
        expires_in: { type: integer, description: access token lifetime in seconds }
    Credentials:
      type: object
      required: [email, password]
      properties:
        email: { type: string, format: email }
        password: { type: string, minLength: 8 }
    RefreshRequest:
      type: object
      required: [refresh_token]
      properties:
        refresh_token: { type: string }
    ChangePasswordRequest:
      type: object
      required: [old_password, new_password]
      properties:
        old_password: { type: string }
        new_password: { type: string, minLength: 8 }
```

Replace `paths: {}` with (this block is extended by later tasks — keep the `paths:` key):
```yaml
paths:
  /auth/register:
    post:
      operationId: register
      summary: Create an account
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/Credentials' }
      responses:
        '201':
          description: created
          content:
            application/json:
              schema: { $ref: '#/components/schemas/TokenPair' }
              example:
                access_token: demo.access
                refresh_token: demo.refresh
                token_type: Bearer
                expires_in: 3600
  /auth/login:
    post:
      operationId: login
      summary: Exchange credentials for tokens
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/Credentials' }
      responses:
        '200':
          description: ok
          content:
            application/json:
              schema: { $ref: '#/components/schemas/TokenPair' }
              example:
                access_token: demo.access
                refresh_token: demo.refresh
                token_type: Bearer
                expires_in: 3600
  /auth/refresh:
    post:
      operationId: refresh
      summary: Exchange a refresh token for a new token pair
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/RefreshRequest' }
      responses:
        '200':
          description: ok
          content:
            application/json:
              schema: { $ref: '#/components/schemas/TokenPair' }
              example:
                access_token: demo.access2
                refresh_token: demo.refresh2
                token_type: Bearer
                expires_in: 3600
  /auth/logout:
    post:
      operationId: logout
      summary: Revoke the current refresh token
      responses:
        '204': { description: no content }
  /auth/password:
    put:
      operationId: changePassword
      summary: Change the account password
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/ChangePasswordRequest' }
      responses:
        '204': { description: no content }
```

- [ ] **Step 5: Run the full validation suite to verify it PASSES**

Run: `cd contracts && npm run validate`
Expected: PASS — lint clean, examples valid, `ok user.json -> User`, `ok token-pair.json -> TokenPair`, local-control script not yet present will error; if `validate:local-control` fails because the script does not exist, that is expected at this stage — run `npm run lint:api && npm run validate:examples && npm run validate:mocks` instead and expect all PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/liushan/Documents/Personal/Languages/Rust/mini_vpn_app
git add contracts/backend-api.openapi.yaml contracts/scripts/validate-mocks.mjs contracts/mock/user.json contracts/mock/token-pair.json
git commit -m "feat(contracts): auth domain (email+password, token pair)"
```

---

## Task 4: Subscription domain

**Files:**
- Create: `contracts/mock/subscription.json`
- Modify: `contracts/backend-api.openapi.yaml`
- Modify: `contracts/scripts/validate-mocks.mjs`

- [ ] **Step 1: Create `contracts/mock/subscription.json`**

```json
{
  "plan": "monthly",
  "status": "active",
  "expires_at": "2026-07-12T08:00:00Z",
  "device_limit": 3
}
```

- [ ] **Step 2: Register the mock in `validate-mocks.mjs`**

Add to `manifest`:
```js
  'subscription.json': 'Subscription',
```

- [ ] **Step 3: Run validator to verify it FAILS**

Run: `cd contracts && npm run validate:mocks`
Expected: FAIL with `MISSING SCHEMA: Subscription for subscription.json` (exit 1).

- [ ] **Step 4: Add the schema + path**

Under `components.schemas`, add:
```yaml
    Subscription:
      type: object
      required: [plan, status, device_limit]
      properties:
        plan: { type: string, enum: [free, monthly, yearly] }
        status: { type: string, enum: [active, expired] }
        expires_at:
          type: [string, "null"]
          format: date-time
          description: null for the free plan
        device_limit: { type: integer, minimum: 1 }
```

Under `paths:`, add:
```yaml
  /subscription:
    get:
      operationId: getSubscription
      summary: Current subscription state for the authenticated user
      responses:
        '200':
          description: ok
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Subscription' }
              example:
                plan: monthly
                status: active
                expires_at: '2026-07-12T08:00:00Z'
                device_limit: 3
```

- [ ] **Step 5: Run the suite to verify it PASSES**

Run: `cd contracts && npm run lint:api && npm run validate:examples && npm run validate:mocks`
Expected: PASS, including `ok subscription.json -> Subscription`.

- [ ] **Step 6: Commit**

```bash
cd /Users/liushan/Documents/Personal/Languages/Rust/mini_vpn_app
git add contracts/backend-api.openapi.yaml contracts/scripts/validate-mocks.mjs contracts/mock/subscription.json
git commit -m "feat(contracts): subscription domain (time-based plan)"
```

---

## Task 5: Devices domain

**Files:**
- Create: `contracts/mock/device.json`
- Create: `contracts/mock/device-list.json`
- Modify: `contracts/backend-api.openapi.yaml`
- Modify: `contracts/scripts/validate-mocks.mjs`

- [ ] **Step 1: Create the mock fixtures**

`contracts/mock/device.json`:
```json
{
  "id": "22222222-2222-4222-8222-222222222222",
  "name": "Sam's MacBook",
  "platform": "macos",
  "last_seen_at": "2026-06-12T08:30:00Z",
  "created_at": "2026-06-01T10:00:00Z"
}
```

`contracts/mock/device-list.json`:
```json
{
  "devices": [
    {
      "id": "22222222-2222-4222-8222-222222222222",
      "name": "Sam's MacBook",
      "platform": "macos",
      "last_seen_at": "2026-06-12T08:30:00Z",
      "created_at": "2026-06-01T10:00:00Z"
    }
  ],
  "device_limit": 3
}
```

- [ ] **Step 2: Register the mocks in `validate-mocks.mjs`**

Add to `manifest`:
```js
  'device.json': 'Device',
  'device-list.json': 'DeviceList',
```

- [ ] **Step 3: Run validator to verify it FAILS**

Run: `cd contracts && npm run validate:mocks`
Expected: FAIL with `MISSING SCHEMA: Device for device.json` (exit 1).

- [ ] **Step 4: Add schemas + paths**

Under `components.schemas`, add:
```yaml
    Device:
      type: object
      required: [id, name, platform, last_seen_at, created_at]
      properties:
        id: { type: string, format: uuid }
        name: { type: string }
        platform: { type: string, enum: [macos, ios, android, windows] }
        last_seen_at: { type: string, format: date-time }
        created_at: { type: string, format: date-time }
    DeviceList:
      type: object
      required: [devices, device_limit]
      properties:
        devices:
          type: array
          items: { $ref: '#/components/schemas/Device' }
        device_limit: { type: integer, minimum: 1 }
    DeviceRegistration:
      type: object
      required: [name, platform]
      properties:
        name: { type: string }
        platform: { type: string, enum: [macos, ios, android, windows] }
```

Under `paths:`, add:
```yaml
  /devices:
    get:
      operationId: listDevices
      summary: List devices bound to the account (for the device_limit cap)
      responses:
        '200':
          description: ok
          content:
            application/json:
              schema: { $ref: '#/components/schemas/DeviceList' }
              example:
                devices:
                  - id: 22222222-2222-4222-8222-222222222222
                    name: Sam's MacBook
                    platform: macos
                    last_seen_at: '2026-06-12T08:30:00Z'
                    created_at: '2026-06-01T10:00:00Z'
                device_limit: 3
    post:
      operationId: registerDevice
      summary: Bind the current device; 409 if device_limit is exceeded
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/DeviceRegistration' }
      responses:
        '201':
          description: created
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Device' }
              example:
                id: 22222222-2222-4222-8222-222222222222
                name: Sam's MacBook
                platform: macos
                last_seen_at: '2026-06-12T08:30:00Z'
                created_at: '2026-06-01T10:00:00Z'
        '409':
          description: device limit exceeded
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Error' }
              example: { code: device_limit_exceeded, message: device limit reached }
  /devices/{deviceId}:
    delete:
      operationId: revokeDevice
      summary: Unbind a device
      parameters:
        - name: deviceId
          in: path
          required: true
          schema: { type: string, format: uuid }
      responses:
        '204': { description: no content }
```

- [ ] **Step 5: Run the suite to verify it PASSES**

Run: `cd contracts && npm run lint:api && npm run validate:examples && npm run validate:mocks`
Expected: PASS, including `ok device.json -> Device` and `ok device-list.json -> DeviceList`.

- [ ] **Step 6: Commit**

```bash
cd /Users/liushan/Documents/Personal/Languages/Rust/mini_vpn_app
git add contracts/backend-api.openapi.yaml contracts/scripts/validate-mocks.mjs contracts/mock/device.json contracts/mock/device-list.json
git commit -m "feat(contracts): devices domain (binding + limit)"
```

---

## Task 6: Nodes domain (shared + dedicated, selectBest)

**Files:**
- Create: `contracts/mock/node-list.json`
- Create: `contracts/mock/select-best.json`
- Modify: `contracts/backend-api.openapi.yaml`
- Modify: `contracts/scripts/validate-mocks.mjs`

- [ ] **Step 1: Create the mock fixtures**

`contracts/mock/node-list.json`:
```json
{
  "nodes": [
    {
      "id": "33333333-3333-4333-8333-333333333333",
      "kind": "shared",
      "region": "US",
      "city": "Los Angeles",
      "latency_ms": 142,
      "load": 0.37,
      "tier": "standard"
    },
    {
      "id": "44444444-4444-4444-8444-444444444444",
      "kind": "shared",
      "region": "JP",
      "city": "Tokyo",
      "latency_ms": 58,
      "load": 0.61,
      "tier": "premium"
    },
    {
      "id": "55555555-5555-4555-8555-555555555555",
      "kind": "dedicated",
      "region": "US",
      "city": "San Jose",
      "label": "my-static-1",
      "static_ip": "203.0.113.9",
      "expires_at": "2026-09-01T00:00:00Z",
      "latency_ms": 130,
      "load": 0.05
    }
  ]
}
```

`contracts/mock/select-best.json`:
```json
{
  "node_id": "44444444-4444-4444-8444-444444444444",
  "reason": "lowest latency among eligible nodes"
}
```

- [ ] **Step 2: Register the mocks in `validate-mocks.mjs`**

Add to `manifest`:
```js
  'node-list.json': 'NodeList',
  'select-best.json': 'SelectBestResponse',
```

- [ ] **Step 3: Run validator to verify it FAILS**

Run: `cd contracts && npm run validate:mocks`
Expected: FAIL with `MISSING SCHEMA: NodeList for node-list.json` (exit 1).

- [ ] **Step 4: Add schemas + paths**

Under `components.schemas`, add:
```yaml
    SharedNode:
      type: object
      required: [id, kind, region, city, latency_ms, load, tier]
      properties:
        id: { type: string, format: uuid }
        kind: { type: string, const: shared }
        region: { type: string }
        city: { type: string }
        latency_ms: { type: integer, minimum: 0 }
        load: { type: number, minimum: 0, maximum: 1 }
        tier: { type: string, enum: [standard, premium] }
    DedicatedNode:
      type: object
      required: [id, kind, region, city, label, static_ip, expires_at, latency_ms, load]
      properties:
        id: { type: string, format: uuid }
        kind: { type: string, const: dedicated }
        region: { type: string }
        city: { type: string }
        label: { type: string }
        static_ip: { type: string, format: ipv4 }
        expires_at: { type: string, format: date-time }
        latency_ms: { type: integer, minimum: 0 }
        load: { type: number, minimum: 0, maximum: 1 }
    Node:
      oneOf:
        - $ref: '#/components/schemas/SharedNode'
        - $ref: '#/components/schemas/DedicatedNode'
      discriminator:
        propertyName: kind
      # NOTE: no `mapping:` — openapi-examples-validator@5 rejects it, and it
      # is redundant here (oneOf + the `kind` const in each variant fully
      # drives discrimination; we hand-write the backend, no OpenAPI codegen).
    NodeList:
      type: object
      required: [nodes]
      properties:
        nodes:
          type: array
          items: { $ref: '#/components/schemas/Node' }
    SelectBestResponse:
      type: object
      required: [node_id, reason]
      properties:
        node_id: { type: string, format: uuid }
        reason: { type: string }
```

Under `paths:`, add:
```yaml
  /nodes:
    get:
      operationId: listNodes
      summary: Shared nodes plus the user's dedicated static-IP nodes
      responses:
        '200':
          description: ok
          content:
            application/json:
              schema: { $ref: '#/components/schemas/NodeList' }
              example:
                nodes:
                  - id: 33333333-3333-4333-8333-333333333333
                    kind: shared
                    region: US
                    city: Los Angeles
                    latency_ms: 142
                    load: 0.37
                    tier: standard
                  - id: 55555555-5555-4555-8555-555555555555
                    kind: dedicated
                    region: US
                    city: San Jose
                    label: my-static-1
                    static_ip: 203.0.113.9
                    expires_at: '2026-09-01T00:00:00Z'
                    latency_ms: 130
                    load: 0.05
  /nodes/select-best:
    post:
      operationId: selectBest
      summary: Server picks the best eligible node (by latency/load)
      responses:
        '200':
          description: ok
          content:
            application/json:
              schema: { $ref: '#/components/schemas/SelectBestResponse' }
              example:
                node_id: 44444444-4444-4444-8444-444444444444
                reason: lowest latency among eligible nodes
```

- [ ] **Step 5: Run the suite to verify it PASSES**

Run: `cd contracts && npm run lint:api && npm run validate:examples && npm run validate:mocks`
Expected: PASS, including `ok node-list.json -> NodeList` and `ok select-best.json -> SelectBestResponse`. (The mixed shared/dedicated array exercises the `oneOf`.)

- [ ] **Step 6: Commit**

```bash
cd /Users/liushan/Documents/Personal/Languages/Rust/mini_vpn_app
git add contracts/backend-api.openapi.yaml contracts/scripts/validate-mocks.mjs contracts/mock/node-list.json contracts/mock/select-best.json
git commit -m "feat(contracts): nodes domain (shared + dedicated, select-best)"
```

---

## Task 7: Purchase stubs (not implemented)

The contract records the purchase surface so clients can wire buttons, but the server returns 501. No mock fixtures (no success body).

**Files:**
- Modify: `contracts/backend-api.openapi.yaml`

- [ ] **Step 1: Add the stub paths under `paths:`**

```yaml
  /purchases/subscription:
    post:
      operationId: purchaseSubscription
      summary: (stub) Buy/renew a subscription — not implemented this version
      responses:
        '501':
          description: not implemented
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Error' }
              example: { code: not_implemented, message: payment not available yet }
  /purchases/dedicated-ip:
    post:
      operationId: purchaseDedicatedIp
      summary: (stub) Buy a dedicated static IP — not implemented this version
      responses:
        '501':
          description: not implemented
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Error' }
              example: { code: not_implemented, message: payment not available yet }
```

- [ ] **Step 2: Run the suite to verify it PASSES**

Run: `cd contracts && npm run lint:api && npm run validate:examples && npm run validate:mocks`
Expected: PASS (no new mocks; lint + examples still clean).

- [ ] **Step 3: Commit**

```bash
cd /Users/liushan/Documents/Personal/Languages/Rust/mini_vpn_app
git add contracts/backend-api.openapi.yaml
git commit -m "feat(contracts): purchase stubs (501, deferred payment)"
```

---

## Task 8: local-control schema ① (semantics only)

**Files:**
- Create: `contracts/local-control.schema.json`
- Create: `contracts/scripts/validate-local-control.mjs`
- Create: `contracts/mock/local-control/cmd-connect.json`
- Create: `contracts/mock/local-control/cmd-auto.json`
- Create: `contracts/mock/local-control/evt-state.json`
- Create: `contracts/mock/local-control/evt-stats.json`
- Create: `contracts/mock/local-control/evt-log.json`

- [ ] **Step 1: Create the sample messages (the failing "test")**

`contracts/mock/local-control/cmd-connect.json`:
```json
{ "type": "connect", "node_id": "33333333-3333-4333-8333-333333333333" }
```

`contracts/mock/local-control/cmd-auto.json`:
```json
{ "type": "auto" }
```

`contracts/mock/local-control/evt-state.json`:
```json
{ "type": "state", "state": "connected" }
```

`contracts/mock/local-control/evt-stats.json`:
```json
{ "type": "stats", "up_bps": 128000, "down_bps": 940000, "up_bytes": 5242880, "down_bytes": 73400320 }
```

`contracts/mock/local-control/evt-log.json`:
```json
{ "type": "log", "level": "info", "message": "tunnel established", "ts": "2026-06-12T08:31:00Z" }
```

- [ ] **Step 2: Create `contracts/scripts/validate-local-control.mjs`**

```js
import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');

const schema = JSON.parse(readFileSync(resolve(root, 'local-control.schema.json'), 'utf8'));
const ajv = new Ajv2020({ strict: false, allErrors: true });
addFormats(ajv);
const validate = ajv.compile(schema);

const dir = resolve(root, 'mock', 'local-control');
let failed = 0;
for (const file of readdirSync(dir).filter(f => f.endsWith('.json'))) {
  const data = JSON.parse(readFileSync(resolve(dir, file), 'utf8'));
  if (validate(data)) { console.log(`ok   local-control/${file}`); }
  else { console.error(`FAIL local-control/${file}`); console.error(validate.errors); failed++; }
}
process.exit(failed ? 1 : 0);
```

- [ ] **Step 3: Run the validator to verify it FAILS (schema missing)**

Run: `cd contracts && npm run validate:local-control`
Expected: FAIL — the script throws because `local-control.schema.json` does not exist yet (ENOENT).

- [ ] **Step 4: Create `contracts/local-control.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://mini-vpn/local-control.schema.json",
  "title": "local-control message",
  "description": "① GUI<->core control messages. Semantics only; the transport (unix socket / XPC / FFI) is bound later when wiring to the core.",
  "oneOf": [
    { "$ref": "#/$defs/CmdConnect" },
    { "$ref": "#/$defs/CmdDisconnect" },
    { "$ref": "#/$defs/CmdSelectNode" },
    { "$ref": "#/$defs/CmdAuto" },
    { "$ref": "#/$defs/EvtState" },
    { "$ref": "#/$defs/EvtStats" },
    { "$ref": "#/$defs/EvtLog" }
  ],
  "$defs": {
    "CmdConnect": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type", "node_id"],
      "properties": {
        "type": { "const": "connect" },
        "node_id": { "type": "string", "format": "uuid" }
      }
    },
    "CmdDisconnect": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type"],
      "properties": { "type": { "const": "disconnect" } }
    },
    "CmdSelectNode": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type", "node_id"],
      "properties": {
        "type": { "const": "select_node" },
        "node_id": { "type": "string", "format": "uuid" }
      }
    },
    "CmdAuto": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type"],
      "properties": { "type": { "const": "auto" } }
    },
    "EvtState": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type", "state"],
      "properties": {
        "type": { "const": "state" },
        "state": { "enum": ["disconnected", "connecting", "connected", "error"] }
      }
    },
    "EvtStats": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type", "up_bps", "down_bps", "up_bytes", "down_bytes"],
      "properties": {
        "type": { "const": "stats" },
        "up_bps": { "type": "integer", "minimum": 0 },
        "down_bps": { "type": "integer", "minimum": 0 },
        "up_bytes": { "type": "integer", "minimum": 0 },
        "down_bytes": { "type": "integer", "minimum": 0 }
      }
    },
    "EvtLog": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type", "level", "message", "ts"],
      "properties": {
        "type": { "const": "log" },
        "level": { "enum": ["debug", "info", "warn", "error"] },
        "message": { "type": "string" },
        "ts": { "type": "string", "format": "date-time" }
      }
    }
  }
}
```

- [ ] **Step 5: Run the validator to verify it PASSES**

Run: `cd contracts && npm run validate:local-control`
Expected: PASS — `ok local-control/cmd-connect.json` and the four other messages, exit 0.

- [ ] **Step 6: Commit**

```bash
cd /Users/liushan/Documents/Personal/Languages/Rust/mini_vpn_app
git add contracts/local-control.schema.json contracts/scripts/validate-local-control.mjs contracts/mock/local-control
git commit -m "feat(contracts): local-control ① message schema (semantics only)"
```

---

## Task 9: README + full-suite green + push

**Files:**
- Create: `contracts/README.md`

- [ ] **Step 1: Create `contracts/README.md`**

````markdown
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
````

- [ ] **Step 2: Run the FULL suite (all four validators) to verify everything is green**

Run: `cd contracts && npm run validate`
Expected: PASS end-to-end — lint clean, examples valid, every mock `ok`, every local-control message `ok`, exit 0.

- [ ] **Step 3: Commit and push**

```bash
cd /Users/liushan/Documents/Personal/Languages/Rust/mini_vpn_app
git add contracts/README.md
git commit -m "docs(contracts): README + validation entrypoint"
git push origin main
```

- [ ] **Step 4: Confirm the core repo was never touched**

Run: `git -C /Users/liushan/Documents/Personal/Languages/Rust/mini_vpn status --porcelain`
Expected: output is unchanged from before this plan (no new lines attributable to this work).

---

## Self-Review

**Spec coverage (spec §5b):**
- email+password auth (register/login/refresh/logout/change-password, access+refresh) → Task 3 ✅
- time-based subscription (plan/status/expires_at/device_limit) → Task 4 ✅
- device binding (register/list/revoke, device_limit) → Task 5 ✅
- nodes shared (region/city/latency/load/tier) + dedicated (kind=dedicated, static_ip, label, expires_at) + selectBest → Task 6 ✅
- payment read-only + not-implemented stubs → Task 4/5 expose status; Task 7 adds 501 stubs ✅
- ① local-control state machine + commands + stats stream + log → Task 8 ✅
- mock fixtures the app reads → every domain task ✅
- contract = consistency boundary, OpenAPI + mock validation → Tasks 1,2,9 toolchain ✅
- isolation: core repo untouched, all artifacts in mini_vpn_app → Task 9 Step 4 verifies ✅

**Placeholder scan:** No TBD/TODO; every schema, path, mock, and script is shown in full. The only intentional "stub" is the 501 purchase contract (a real contract decision, not a plan gap).

**Type consistency:** `User`, `TokenPair`, `Subscription`, `Device`, `DeviceList`, `SharedNode`, `DedicatedNode`, `Node`, `NodeList`, `SelectBestResponse`, `Error` referenced by `$ref` exactly as defined. local-control `$defs` names match the `oneOf` refs. Mock manifest keys match created filenames. `kind` const values (`shared`/`dedicated`) match the discriminator mapping and the mock data.

**Note on the `validate` aggregate:** Tasks 3–7 run the suite *without* `validate:local-control` (that script is created in Task 8). Each of those tasks intentionally lists the three-validator command, not `npm run validate`. The full four-validator `npm run validate` is first expected green in Task 9.
