# kavach backend setup (Mac 2, Module 0)

Everything here runs offline. No NVIDIA, Photon or SpacetimeDB account is needed for the HTTP API or its tests.

## Observed toolchain (2026-11-08)

| Tool | Version |
|---|---|
| Node.js | v22.13.1 (backend requires >= 22) |
| npm | 11.14.1 |
| TypeScript | 5.9.3 (backend), 5.x (spacetimedb) |
| Fastify | 5.12.8 |
| Ajv / ajv-formats | 8.20.0 / 3.0.1 — JSON Schema **draft 2020-12** |
| Vitest | 3.2.4 |
| SpacetimeDB CLI / `spacetimedb` npm | 2.14.1 / 2.14.1 |

## Layout

```text
backend/            HTTP API (Fastify + TypeScript). Self-contained package.json.
  src/app.ts          app factory (used by tests via fastify.inject)
  src/server.ts       listener entry point
  src/config.ts       HOST / PORT / ANALYSIS_PROVIDER
  src/contracts.ts    compiles shared/contracts/*.schema.json with Ajv (runtime validation)
  src/routes/         health.ts, analyze.ts
  src/risk/           types, RiskAnalyzer interface, MockRiskAnalyzer, classify (score -> level)
  src/middleware/     error envelope + framework error mapping
  tests/              Vitest suites (offline)
shared/contracts/   canonical JSON Schemas + examples (source of truth for iOS Codable models)
spacetimedb/        SpacetimeDB 2.x TypeScript module
agent/              Photon placeholder (not connected), see agent/README.md
```

## Install, test, build, run

```bash
cd backend
npm install
npm test            # vitest run — 86 tests, offline
npm run typecheck   # tsc --noEmit
npm run build       # tsc -> backend/dist
npm run dev         # tsx watch, http://127.0.0.1:3001
npm start           # runs the built dist/server.js
```

Optional local overrides: `cp backend/.env.example backend/.env`. Both `dev` and `start` load
`backend/.env` if it exists. `backend/.env` is gitignored (verified with `git check-ignore`).

| Variable | Default | Notes |
|---|---|---|
| `HOST` | `127.0.0.1` | Loopback only by default. |
| `PORT` | `3001` | Integer 1–65535. |
| `ANALYSIS_PROVIDER` | `mock` | `nvidia` is refused until Module 1 implements it. |

Request body limit is 32 KiB. Request timeout is 15 s.

## Smoke test (observed output, 2026-11-08)

```bash
curl -i http://127.0.0.1:3001/health
# HTTP/1.1 200 OK
# content-type: application/json; charset=utf-8
# {"status":"ok","service":"kavach-api","version":"0.1.0","time":"2026-11-08T09:00:03.993Z"}

curl -i -X POST http://127.0.0.1:3001/api/v1/analyze \
  -H 'Content-Type: application/json' \
  -d '{"kind":"call","content":"My bank says to urgently wire money."}'
# HTTP/1.1 200 OK
# {"analysisId":"abd723f5-…","kind":"call","riskScore":92,"riskLevel":"critical",
#  "summary":"This description contains signs of a possible bank impersonation scam.",
#  "signals":[…3 items…],"recommendedActions":[…2 items…],"source":"mock",
#  "requiresHumanReview":false,"analyzedAt":"2026-11-08T09:00:04.007Z"}

curl -i -X POST http://127.0.0.1:3001/api/v1/analyze \
  -H 'Content-Type: application/json' \
  -d '{"kind":"unknown","content":"test"}'
# HTTP/1.1 400 Bad Request
# {"error":{"code":"VALIDATION_ERROR","message":"The \"kind\" field is missing or invalid.","requestId":"7f92a46c-…"}}
```

Also observed: bad JSON → `400 INVALID_JSON`, 40 KB body → `413 PAYLOAD_TOO_LARGE`, and the
listener bound to `127.0.0.1:3001` only.

## Contract behaviour

Schemas: `shared/contracts/{analyze-request,risk-assessment,health,error}.schema.json`.
Examples: `shared/contracts/examples/*.json`. The backend validates **requests and its own
responses** against these same files at runtime, so they cannot drift silently.

- The server trims `content`, `phoneNumber` and `context`. Empty optional strings count as absent.
- Unknown properties are **rejected** (`additionalProperties: false`), including `reportId`.
- `phoneNumber`: `^\+[1-9][0-9]{0,14}$`. Lengths are counted in Unicode code points.
- `riskLevel` is always derived from `riskScore` on the server (0–24 low, 25–49 guarded,
  50–74 high, 75–100 critical). The schema enforces the pairing too.
- If the analyzer returns anything off-contract, the API answers `500 INTERNAL_ERROR`. It never
  passes along arbitrary JSON.
- Error codes: `INVALID_JSON` 400, `VALIDATION_ERROR` 400, `PAYLOAD_TOO_LARGE` 413,
  `UNSUPPORTED_MEDIA_TYPE` 415 (body not JSON), `NOT_FOUND` 404, `INTERNAL_ERROR` 500.
  `ANALYZER_UNAVAILABLE` 503 is reserved for Module 1.
- Every response carries an `x-request-id` header. It matches `error.requestId` on errors.

### Mock analyzer rules (`src/risk/MockRiskAnalyzer.ts`)

Lowercased `content` + `context` are checked in order. The first match wins.

| Rule | Trigger (both groups needed where shown) | Score / level |
|---|---|---|
| one-time code | code/otp/one-time/passcode/verification **and** tell/share/send/read/give | 95 critical |
| bank impersonation | bank/banking/financial **and** transfer/wire/send money/move money/payment | 92 critical |
| delivery fee link | deliver/package/parcel/shipment/courier **and** fee/pay/link/click/http | 65 high |
| unknown callback | unknown/unfamiliar/unrecognized/private/blocked + number/caller/contact/sender/phone, "no caller id", "call … back", "callback" | 35 guarded |
| benign | friend/family/lunch/dinner/plans/confirmed/appointment | 10 low |
| no match | — | 40 guarded, `requiresHumanReview: true`, summary says it is a simulated demo |

This is fixture matching for a demo, not fraud detection. It never fetches URLs and never puts
user text into its output.

## Logging

Logs are JSON (pino via Fastify). They contain only request id, method, path (query string
stripped) and status code. Request bodies, headers, query strings, remote addresses and error
messages/stacks are never logged. Tests assert this, and the live server log was checked for
submitted text.

## Enabling LAN access for a physical iPhone (later modules, deliberate decision)

1. In `backend/.env` set `HOST=0.0.0.0` (or the Mac's LAN IP). The server will log a warning.
2. Allow incoming connections for `node` in macOS Firewall when prompted.
3. On the iPhone use `http://<mac-lan-ip>:3001`. This is **plain HTTP**: iOS App Transport
   Security will block it unless the iOS project adds a development-only exception. That is
   Mac 1's decision.
4. Use only on a trusted network, with no production credentials, and switch back to
   `127.0.0.1` afterwards. Never port-forward or tunnel it to the Internet.

## SpacetimeDB module (`spacetimedb/`)

One public, non-personal table `development_status(component PK, status, updatedAt)` and one
reducer `set_development_status(component, status)`. The reducer inserts or updates the row and
accepts only `[a-z0-9_-]` names (component ≤ 64 chars, status ≤ 32). Tables are private by
default. Reports and circle data in later modules must stay private and be exposed only through
caller-aware views/reducers.

```bash
cd spacetimedb
npm install
npx tsc --noEmit             # typecheck
spacetime build              # VERIFIED
spacetime start              # local server on 127.0.0.1:3000 (separate terminal)
npm run publish:local        # spacetime publish --server local kavach-dev -y --no-config
npm run call:local -- backend module-0-ready
cd /tmp && spacetime sql --server local kavach-dev "SELECT component, status FROM development_status"
npm run generate             # regenerate agent/photon-worker/src/module_bindings
```

**`--no-config` matters.** The repo root has `spacetime.json` (server `maincloud`) and
`spacetime.local.json` (database `kavach-qnc3a`). The CLI picks these up from any subdirectory
and **silently replaces the database name you pass** with `kavach-qnc3a`. Use `--no-config`,
or run `spacetime sql` from outside the repo.

Module entry files may export only SpacetimeDB values (tables, reducers, lifecycle hooks).
Exporting a plain constant fails publish with `exporting something that is not a spacetime export`.

**Maincloud:** the database `kavach-qnc3a` was published earlier with an empty schema. It has
**not** been republished with this Module 0 schema. Module 0 needs no cloud deploy. Republish
deliberately later with `spacetime publish --server maincloud kavach-qnc3a` from `spacetimedb/`.

## Planned integrations: NOT connected

- **NVIDIA (Module 1):** a provider behind `RiskAnalyzer`, selected by `ANALYSIS_PROVIDER=nvidia`.
  Configured by `NVIDIA_API_KEY` / `NVIDIA_MODEL` in `backend/.env`. No NVIDIA request has been made.
- **Photon (Module 4):** see `agent/README.md`.
- No deployment exists. The API is local-only.
