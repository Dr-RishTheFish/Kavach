# Kavach Final Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the real Kavach backend: authenticated accounts, private reports, trusted circles with live alerts, real APNs push and a real Photon iMessage agent, deployed over HTTPS. The NVIDIA analysis from Module 1 is preserved.

**Architecture:** The Fastify API (`backend/`) stays the only authorization boundary. Product state lives in **private** SpacetimeDB 2.x tables (`spacetimedb/`), written only through reducers that accept calls from the backend's service identity. The backend reaches them through a `Store` interface: in-memory for offline tests, SpacetimeDB HTTP for real use. Live updates go to iOS over authenticated SSE backed by persisted, sequenced alerts. A durable outbox drives APNs (Node `http2` + ES256 JWT) and Photon replies. The Photon worker (`agent/photon-worker`) is a separate process that calls the backend over an internal, token-protected route.

**Tech Stack:** Node ≥ 22, TypeScript 5.9, Fastify 5.12, Ajv 8 (JSON Schema 2020-12), Vitest 3.2, SpacetimeDB 2.14.1 (TypeScript module + HTTP API), `jose` (Apple JWKS / session JWT), Node `http2` + `crypto` (APNs), `spectrum-ts` 12.15.0 (Photon).

**Spec:** `context_and_plan/KAVACH_FINAL_BUILD_MAC2_CLAUDE.md` (untracked shared brief; Edition 1.0, 2026-11-08). Baseline: `docs/handoffs/final-backend-baseline.md`.

## Sequencing update (2026-11-08)

The team will build the **final UI module first**. Phases B–F run **after** it and must be refined
against the UI that ships. Before starting Phase B: read Person 1's final-UI handoff and their answers
to `docs/handoffs/person2-to-person1-final-ui.md` §9, then update routes, schemas and task details here.
Phase A (baseline + physical iPhone check) can proceed now.

## How this plan is organised

The spec covers five independent subsystems, each with its own external gate. Per the writing-plans
scope rule this document holds:

1. **Roadmap**: phases, dependencies, architecture decisions and human/external gates (all phases).
2. **Detailed tasks for Phases A and B**, which can start now.
3. **Phase C–F outlines** with the interfaces they consume. Each gets its own detailed plan
   (`docs/superpowers/plans/2026-11-08-final-backend-phase-<x>.md`) when the previous phase's interfaces
   are real, so later tasks aren't written against guessed signatures.

## Global Constraints

- Preserve `POST /api/v1/analyze`, its request/response schemas, `source: mock|nvidia`, `analysisId`, and fail-closed `503 ANALYZER_UNAVAILABLE`. Never rename `analysisId` to `reportId`.
- Risk bands: 0–24 low, 25–49 guarded, 50–74 high, 75–100 critical. Heuristic, not a probability.
- Error envelope `{ "error": { "code", "message", "requestId" } }` + `x-request-id` header on every response.
- UUIDs for all domain resource IDs. Validate every payload against `shared/contracts/` schemas; bound sizes, pages (limit ≤ 50) and bodies (32 KiB).
- Never log request text, phone numbers, invite codes, push tokens, bearer/refresh tokens, `.p8` contents, provider bodies or model output.
- Secrets only in ignored env files / secret stores; `.env.example` placeholders only. No secrets in `ios/`.
- No SpacetimeDB table with user data may be `public: true`. Every owner/circle check uses the **authenticated actor**, never a client-supplied user ID.
- Save report and share-to-circle are separate, explicit consents, default **off**. Pushes only on a user-confirmed share of a high/critical report.
- Never simulate a provider success: APNs, Photon and Apple results are `simulated` in dry-run transports and labelled as such everywhere.
- Owned paths: `backend/`, `spacetimedb/`, `agent/`, `shared/contracts/`, backend `docs/`, `scripts/`. Do not edit `ios/`.
- No force-push, `reset --hard`, destructive Maincloud publish, or merge without human approval.

## Review Focus

- **Expired access token mid-request on iOS:** an expired access token must yield `401 UNAUTHENTICATED` (never 403/500), so the app knows to refresh. → test `expired access token returns 401 UNAUTHENTICATED` in Task B4.
- **Refresh token replayed after rotation (stolen token):** the whole session must be revoked, not just the request rejected. → test `reusing a rotated refresh token revokes the session` in Task B4.
- **Same Idempotency-Key retried with a different body:** the response must be `409 IDEMPOTENCY_CONFLICT`; the same body returns the original 201 with an identical `reportId`. → tests in Task B6.
- **Report saved with an `analysisId` the server never issued, or one older than the reference TTL:** the report is saved with `assessment: null`, never with client-claimed scores. → test `unknown or expired analysisId saves without assessment` in Task B6.
- **SpacetimeDB unreachable while the API is up:** report routes return `503 STORE_UNAVAILABLE`, and `/api/v1/analyze` keeps working. → test `store outage returns 503 and analyze still works` in Task B7.

---

## Roadmap

| Phase | Delivers | Depends on | External gate (human / provider) | Gate to pass |
|---|---|---|---|---|
| **A** Baseline freeze | Audit, contract freeze, real iPhone → NVIDIA check | — | Person 1 runs the physical iPhone on the Mac 2 LAN | Tests green; iPhone result PASS or BLOCKED recorded |
| **B** Auth + private reports | Apple sign-in, sessions, test-account fallback, report CRUD in SpacetimeDB | A | Sign in with Apple capability on team `L3ZM5X4NF8` (Person 1) for real Apple tokens | A owns reports; B/C denied; restart persists; bad tokens fail |
| **C** Circles + live feed | Circles, invites, members, sanitized shares, alerts, SSE with catch-up | B | — | Two users share/revoke; outsider denied; dedupe + reconnect proven |
| **D** APNs | Device registry, ES256 HTTP/2 client, outbox worker, retries/invalidation | C | Push capability + APNs `.p8` (Team ID, Key ID) from Person 1's team; signed physical iPhone | Real APNs 200 **and** banner seen on backgrounded device |
| **E** Photon agent | Spectrum worker, ≤3-question flow via internal analysis, account linking, consented save/share | B, C | **Managed iMessage line provisioned** in Photon project `kavach` | Real Messages inbound + outbound; linked save only after confirm |
| **F** Deploy + regression | HTTPS host for API + workers, rate limits, demo runbook, final matrix | B–E | **Hosting provider choice + account** | All gates PASS or named BLOCKED |

D and E can run in parallel after C. Mac 1 needs schemas at the B, C, D and E checkpoints;
each checkpoint ships its schemas and curl fixtures before the phase is closed.

## Architecture decisions (deliberate, recorded before code)

| # | Decision | Why | Revisit if |
|---|---|---|---|
| D1 | Backend is the only client-facing authority; iOS never talks to SpacetimeDB directly | Spec §3: private tables, backend authorization; avoids experimental RLS | A scoped, tested view becomes necessary |
| D2 | Backend → SpacetimeDB over the **HTTP API** as the module owner/service identity: reducers for writes (`POST /v1/database/:db/call/:reducer`) and owner SQL or procedures for reads | No long-lived client SDK in the API process; reducers re-check `ctx.sender == service identity` | Task B1 spike shows owner SQL can't read private tables, in which case use procedures |
| D3 | `Store` interface with `MemoryStore` (unit tests) and `SpacetimeStore` (real); one shared contract test suite runs against both | Keeps `npm test` offline; proves the real store with the same assertions | — |
| D4 | Auth: Sign in with Apple (`jose` + Apple JWKS; `iss=https://appleid.apple.com`, `aud=APPLE_CLIENT_ID=com.rishthefish.kavach`, `exp`, nonce) with **server-issued single-use nonces**; sessions = 15-min HS256 access JWT + opaque 30-day refresh token stored as SHA-256, rotated with reuse detection | Spec §4 identity design and auth edge tests | — |
| D5 | Fallback: `AUTH_TEST_ACCOUNTS=enabled` exposes `POST /api/v1/auth/test` (server-configured accounts, scrypt-hashed passwords), labelled "Test account" in `/me` (`authMethod: "test"`) | Spec §4 backup route when Apple isn't provisioned; never presented as Apple login | Apple capability ready, in which case keep it disabled in deploy |
| D6 | Scores on saved reports come only from a server-held **analysis reference** (in-memory, 60-min TTL, no user text), keyed by `analysisId`; otherwise `assessment: null` | Spec §12 safety caveat: never trust client scores | References must survive restarts, in which case move to a private table |
| D7 | Live feed = authenticated SSE (`GET /api/v1/events`, bearer header, `Last-Event-ID` = per-user monotonic sequence) over persisted alerts; APNs is wake-up only | Spec §6 | — |
| D8 | APNs with Node `http2` + `crypto.sign('sha256', …, {dsaEncoding:'ieee-p1363'})` (no extra dependency); JWT cached ≤ 50 min | Spec §7; avoids an unmaintained library | — |
| D9 | Agent analysis goes through internal `POST /internal/v1/analyze` (bearer `AGENT_SERVICE_TOKEN`, loopback/private network), reusing `createAnalyzer` | Spec §8: same NVIDIA pipeline, secured boundary | — |
| D10 | Env names normalised to the spec's §13 inventory; root `.env` `NIM_*` mapped once in `docs/setup/deployment.md` | Spec §13 | — |

## New error codes (additive; documented in `shared/contracts/error.schema.json` description)

`UNAUTHENTICATED` 401 (missing/invalid/expired access token), `FORBIDDEN` 403 (authenticated but not
allowed), `IDEMPOTENCY_CONFLICT` 409, `INVITE_INVALID` 410 (expired/used/revoked invite; Phase C),
`RATE_LIMITED` 429 (Phase F), `STORE_UNAVAILABLE` 503. Existing codes unchanged. Cross-user reads of
a private resource return **404 NOT_FOUND** (not 403) so existence isn't leaked.

---

## Phase A — Baseline freeze

### Task A1: Baseline audit and contract freeze

**Files:**
- Create: `docs/handoffs/final-backend-baseline.md`
- Test: `scripts/module0-integration.sh` (existing)

**Interfaces:**
- Produces: the frozen contract SHA (`e9dfbea`) and the external-gate status list that every later phase references.

- [ ] **Step 1:** Run `scripts/module0-integration.sh --with-spacetime --with-simulator`. Expected: exit 0; backend 177/177, Swift host 34/34, simulator unit + 3 UI tests pass.
- [ ] **Step 2:** Write `final-backend-baseline.md` with the spec §1 fields: branch/SHA, merged Module 1 features, tree cleanliness, schemas, credential **presence only**, Photon line state, Apple entitlement state, Mac 1 needs.
- [ ] **Step 3:** Commit: `docs(backend): final-build baseline audit and plan`.

### Task A2: Physical iPhone → Mac 2 → NVIDIA check (human-run)

**Files:**
- Modify: `docs/handoffs/final-backend-baseline.md` (Result section)

- [ ] **Step 1:** On Mac 2, `cd backend && npm run dev` (existing `backend/.env`: `HOST=0.0.0.0`, `ANALYSIS_PROVIDER=nvidia`).
- [ ] **Step 2:** Person 1 sets Live mode to `http://Chidatmas-MacBook-Pro.local:3001` on the iPhone and analyzes one fictional bank-impersonation text. Expected: result card shows "Analyzed with NVIDIA"; the Mac 2 log shows `"outcome":"ok"` with no request text.
- [ ] **Step 3:** Record PASS with timestamp/device, or BLOCKED with the exact failure (firewall, ATS, network). Commit.

---

## Phase B — Auth and private persistence

### Task B1: SpacetimeDB read-path spike (decides D2)

**Files:**
- Create: `spacetimedb/src/product/service.ts` (private `service_config` table, `init` records `ctx.sender` as the service identity)
- Create: `scripts/spike-spacetime-private-read.sh`

**Interfaces:**
- Produces: `SPACETIME_READ_MODE=sql|procedure`, recorded in `docs/setup/spacetimedb.md` and used by Task B3.

- [ ] **Step 1:** Publish to a local server (`spacetime start`; `spacetime publish --server local kavach-dev -y --no-config`), with a private table holding one row.
- [ ] **Step 2:** As the owner, `POST http://127.0.0.1:3000/v1/database/kavach-dev/sql` with `SELECT * FROM service_config`. Expected: the row is returned with the owner token, and a fresh anonymous identity token gets an error or 0 rows.
- [ ] **Step 3:** If owner SQL can't read private rows, define a procedure returning the row and confirm `POST …/call/<procedure>` returns it. Record the chosen mode. Commit.

### Task B2: v1 contracts for auth, profile and reports

**Files:**
- Create: `shared/contracts/v1/{auth-nonce-response,auth-apple-request,auth-test-request,auth-refresh-request,session-response,me-response,report-create-request,report,report-list}.schema.json` + `shared/contracts/v1/examples/*.json`
- Modify: `shared/contracts/error.schema.json` (description only: new codes)
- Modify: `backend/src/contracts.ts` (compile v1 schemas into `validators.v1.*`)
- Test: `backend/tests/contractsV1.test.ts`

**Interfaces:**
- Produces: `validators.v1.<name>` Ajv validators; JSON shapes:
  - `SessionResponse { accessToken: string, accessTokenExpiresAt: date-time, refreshToken: string, refreshTokenExpiresAt: date-time, user: Me }`
  - `Me { userId: uuid, displayName: string|null, authMethod: "apple"|"test", createdAt: date-time }`
  - `ReportCreateRequest { consent: true, kind: call|sms|message|url, analysisId?: uuid, description?: string(1..5000), notes?: string(1..1000) }` (no client scores accepted; `additionalProperties:false`)
  - `Report { reportId: uuid, analysisId: uuid|null, kind, description: string|null, notes: string|null, assessment: { riskScore, riskLevel, source, summary, signals, recommendedActions, verifiedByServer: true } | null, createdAt: date-time }`
  - `ReportList { items: Report[], nextCursor: string|null }`

- [ ] **Step 1: Failing tests:** every example validates; `report-create-request` rejects `riskScore`, `consent:false`, missing `consent`, unknown keys; `report` rejects `assessment.verifiedByServer:false`; Module 0 examples still validate.
- [ ] **Step 2:** Run `cd backend && npx vitest run tests/contractsV1.test.ts`. Expected: FAIL (schemas missing).
- [ ] **Step 3:** Write the schemas/examples (draft 2020-12, `$id` under `https://kavach.local/contracts/v1/`) and compile them in `contracts.ts`.
- [ ] **Step 4:** Run the full suite. Expected: all pass. Commit `feat(contracts): v1 auth and report schemas`.

### Task B3: Store interface, MemoryStore, SpacetimeStore + product tables

**Files:**
- Create: `backend/src/store/Store.ts`, `backend/src/store/memoryStore.ts`, `backend/src/store/spacetimeStore.ts`, `backend/src/store/spacetimeHttp.ts`
- Create: `spacetimedb/src/product/{users,sessions,nonces,reports}.ts`; Modify: `spacetimedb/src/index.ts`, `spacetimedb/src/tables.ts`
- Test: `backend/tests/store.contract.ts` (shared suite), `backend/tests/store.memory.test.ts`, `backend/tests/store.spacetime.itest.ts` (run by `npm run test:spacetime`, needs the local server)

**Interfaces:**
- Produces `interface Store` (all async, throwing `StoreUnavailableError` on transport failure):
  - `upsertUser({ authMethod, authSubject, displayName }): Promise<UserRecord>`; `getUser(userId): Promise<UserRecord|null>`
  - `createSession({ sessionId, userId, refreshHash, expiresAt }): Promise<void>`; `getSessionByRefreshHash(hash)`; `rotateSession(sessionId, { oldHash, newHash, expiresAt }): Promise<'rotated'|'reuse_detected'|'not_found'>`; `revokeSession(sessionId)`
  - `consumeNonce(nonceHash, now): Promise<boolean>` (true once, then false); `createNonce(nonceHash, expiresAt)`
  - `createReport(rec: ReportRecord, idempotencyKey: string, requestHash: string): Promise<{ report: ReportRecord, replayed: boolean } | { conflict: true }>`; `listReports(ownerId, { cursor, limit })`; `getReport(ownerId, reportId)`; `softDeleteReport(ownerId, reportId): Promise<boolean>`
- Reducers (all private tables; each asserts `ctx.sender` equals the `service_config` identity): `upsert_user`, `create_session`, `rotate_session`, `revoke_session`, `create_nonce`, `consume_nonce`, `create_report`, `soft_delete_report`. Indexes: `user_profile(authSubject)`, `session(refreshHash)`, `scam_report(ownerUserId, createdAt)`, `idempotency(ownerUserId, key)`.

- [ ] **Step 1: Shared contract suite (failing):** `owner sees own report and nobody else's`, `soft-deleted report disappears from list and get`, `same idempotency key + same hash replays`, `same key + different hash conflicts`, `nonce consumable exactly once`, `expired nonce not consumable`, `rotate detects reuse of an old hash`, `list paginates newest-first with stable cursor, limit capped at 50`.
- [ ] **Step 2:** Run `npx vitest run tests/store.memory.test.ts`. Expected: FAIL.
- [ ] **Step 3:** Implement `MemoryStore`. Run. Expected: PASS.
- [ ] **Step 4:** Implement tables/reducers and `SpacetimeStore` (owner token from `SPACETIME_AUTH_TOKEN`, URI `SPACETIME_URI`, DB `SPACETIME_DB_NAME`, read mode from B1). `spacetime build` succeeds; `npm run test:spacetime` against a local publish passes the same suite, **including after a `spacetime start` restart** (persistence).
- [ ] **Step 5:** Typecheck; offline suite green. Commit `feat(store): private SpacetimeDB product tables behind Store interface`.

### Task B4: Sessions, test-account sign-in and `requireAuth`

**Files:**
- Create: `backend/src/auth/{tokens.ts,sessions.ts,requireAuth.ts,testAccounts.ts}`, `backend/src/routes/{auth.ts,me.ts}`
- Modify: `backend/src/config.ts` (`SESSION_SIGNING_KEY` ≥ 32 bytes, `AUTH_TEST_ACCOUNTS=disabled|enabled`, `AUTH_TEST_ACCOUNTS_FILE`), `backend/src/app.ts` (register routes; `buildApp({ store, … })`)
- Test: `backend/tests/auth.sessions.test.ts`

**Interfaces:**
- Consumes: `Store` (B3), `validators.v1` (B2).
- Produces: `requireAuth` preHandler setting `request.actor: { userId: string, sessionId: string }`; `issueSession(store, userId) → SessionResponse`; routes `POST /api/v1/auth/test`, `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`, `GET /api/v1/me`.

- [ ] **Step 1: Failing tests:** `test sign-in disabled by default returns 404`, `valid test credentials return a session`, `wrong password returns 401 UNAUTHENTICATED with a fixed message`, `GET /me without token returns 401`, `expired access token returns 401 UNAUTHENTICATED`, `tampered access token returns 401`, `refresh rotates both tokens`, `reusing a rotated refresh token revokes the session`, `logout revokes the session so refresh and /me fail`, `/me reports authMethod "test"`, `logs never contain tokens or passwords`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement: access JWT HS256 via `jose` (`sub`=userId, `sid`, `exp`=15 min); refresh token = 32 random bytes base64url, store SHA-256 only, 30-day expiry; scrypt for test passwords.
- [ ] **Step 4:** Run full suite + typecheck. Expected: PASS. Commit `feat(auth): sessions, test-account fallback and requireAuth`.

### Task B5: Sign in with Apple verification

**Files:**
- Create: `backend/src/auth/apple.ts`; Modify: `backend/src/routes/auth.ts`, `backend/src/config.ts` (`APPLE_CLIENT_ID`, `APPLE_JWKS_URL` default `https://appleid.apple.com/auth/keys`)
- Test: `backend/tests/auth.apple.test.ts` (local RSA keypair + local JWKS; no network)
- Create: `docs/setup/apple-auth.md`

**Interfaces:**
- Produces: `verifyAppleIdentityToken(token, { clientId, nonce, jwks, now }) → { subject: string, email?: string }`; routes `POST /api/v1/auth/apple/nonce` → `{ nonce, expiresAt }` and `POST /api/v1/auth/apple` `{ identityToken, nonce, displayName? }` → `SessionResponse`.

- [ ] **Step 1: Failing tests:** `valid token with matching hashed nonce signs in`, `invalid signature rejected`, `wrong audience rejected`, `wrong issuer rejected`, `expired token rejected`, `nonce mismatch rejected`, `replayed nonce rejected on second use`, `unissued nonce rejected`, `same Apple subject maps to the same userId`. All failures return `401 UNAUTHENTICATED`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement with `jose.createRemoteJWKSet` (injectable JWKS for tests). The token's `nonce` claim must equal `sha256hex(nonce)` (Apple native flow). The nonce is consumed via `Store.consumeNonce`.
- [ ] **Step 4:** Run full suite. Expected: PASS. Write `apple-auth.md`: capability on team `L3ZM5X4NF8`, `aud` = bundle ID, nonce flow for Mac 1, how real-token proof will be recorded. Commit.
- [ ] **Step 5 (gate, human):** Person 1 signs in on a device; record a sanitized result (`authMethod:"apple"`, no token) or `BLOCKED: APPLE_SIGN_IN_CAPABILITY`.

### Task B6: Report routes with analysis references and idempotency

**Files:**
- Create: `backend/src/analysis/references.ts`, `backend/src/http/idempotency.ts`, `backend/src/routes/reports.ts`
- Modify: `backend/src/routes/analyze.ts` (record a reference after a validated success; response unchanged)
- Test: `backend/tests/reports.test.ts`

**Interfaces:**
- Consumes: `requireAuth`/`request.actor` (B4), `Store` (B3).
- Produces: `AnalysisReferences.put(assessment: RiskAssessment)` / `.get(analysisId): VerifiedAssessment|null` (60-min TTL, max 10 000 entries, no request text); routes `POST/GET /api/v1/reports`, `GET/DELETE /api/v1/reports/:reportId`.

- [ ] **Step 1: Failing tests:** `create requires auth`, `create requires consent:true`, `create with a fresh analysisId copies the server assessment with verifiedByServer`, `unknown or expired analysisId saves without assessment`, `client-supplied riskScore is rejected 400`, `Idempotency-Key required (400 without)`, `same key and body returns the same reportId`, `same key, different body returns 409 IDEMPOTENCY_CONFLICT`, `user B gets 404 for user A's report`, `list returns only own reports with nextCursor`, `delete hides the report and is idempotent`, `analyze response is byte-for-byte the v0 contract`, `logs contain no description or notes`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. Request hash = SHA-256 of the canonical JSON body.
- [ ] **Step 4:** Run full suite. Expected: PASS. Commit `feat(reports): private report CRUD with verified assessments`.

### Task B7: Wiring, outage behaviour, Phase B checkpoint

**Files:**
- Modify: `backend/src/server.ts` (`createStore(config)`), `backend/.env.example`, `docs/backend-setup.md`
- Create: `docs/contracts/ios-api-v1.md` (auth + reports section), `docs/setup/spacetimedb.md`, `docs/architecture/final-backend.md` (trust boundaries, threat model, D1–D10, auth/report sequence diagrams; extended in C–F)
- Test: `backend/tests/storeOutage.test.ts`; `scripts/module0-integration.sh` (extend with a `--with-phase-b` local two-user curl flow)

- [ ] **Step 1: Failing test:** `store outage returns 503 and analyze still works` (Store throwing `StoreUnavailableError` → `503 STORE_UNAVAILABLE`; `/api/v1/analyze` still 200).
- [ ] **Step 2:** Implement the mapping and wiring; run. Expected: PASS.
- [ ] **Step 3: Gate:** local SpacetimeDB, two test users: A creates, B gets 404, unauthenticated gets 401; restart the server and SpacetimeDB, and A's report is still listed. Record the results in `docs/testing/final-e2e-matrix.md`.
- [ ] **Step 4:** Publish the checkpoint SHA, schemas and curl fixtures to Person 1 (doc + PR). **Do not** publish to Maincloud without approval. Commit.

---

## Phase C–F outlines (detailed plans written at each phase start)

**C — Circles and live feed.** Consumes `requireAuth`, `Store`. Adds tables `trusted_circle`, `circle_member`, `circle_invite` (code SHA-256, 15-min expiry, `maxUses`), `circle_share` (sanitized `preview` ≤ 140 chars, `consentAt`), `circle_alert` (per-user `seq`); routes in spec §4; `GET /api/v1/events` SSE (15 s heartbeat, `Last-Event-ID`, replay ≤ 500 events, closes on session revoke/membership loss). Key tests: outsider 404, expired/reused invite `410 INVITE_INVALID`, duplicate share → one alert, removed member's open stream receives `membership.revoked` then closes, reconnect replays the missed event once.

**D — APNs.** Consumes alerts from C. Adds `device_registration` (token stored encrypted with `DEVICE_TOKEN_KEY`, never logged), `notification_outbox` (unique `(alertId, deviceId)`), `POST/DELETE /api/v1/devices`, `ApnsClient` (sandbox/production endpoints, `apns-topic`, `apns-push-type: alert`, `apns-id`), worker with exponential backoff + jitter (max 5 attempts), `410`/`BadDeviceToken` → invalidate, `403` → diagnostic blocker. `APNS_MODE=disabled|dry-run|sandbox|production`; `dry-run` reports `simulated`. Tests against a local HTTP/2 fake APNs server. Gate: real token, APNs 200, banner on a backgrounded iPhone.

**E — Photon agent.** Consumes `/internal/v1/analyze` (D9), `Store`, shares from C. Worker: `Spectrum({ projectId, projectSecret, providers: [imessage.config()] })` (`terminal.config()` for tests); dedupe on provider message ID; skip outbound/self/non-text; commands HELP/CANCEL/START OVER/STOP; ≤ 3 questions; linking `POST /api/v1/agent/link/start` → 6-digit code (10 min, single use, hashed) sent by the user in Messages, then `POST /api/v1/agent/link/confirm` in the authenticated app shows the matching conversation for approval; SAVE and SHARE each need explicit confirmation. `GET /api/v1/agent` returns `PHOTON_AGENT_ADDRESS` (or `available:false`). Gate: real Messages round trip; `BLOCKED: PHOTON_MANAGED_LINE` if no line.

**F — Deployment and regression.** HTTPS host for API + two workers (needs provider decision), `@fastify/rate-limit`, security headers, CORS allow-list, readiness that never prints secrets, rollback notes, the two-user demo runbook (spec §16) and the final `docs/testing/final-e2e-matrix.md` and `docs/handoffs/person2-final.md`.

## Human decisions and external prerequisites (needed before the named phase)

| Needed by | Item | Owner |
|---|---|---|
| A2 | Run the physical iPhone against Mac 2 (same Wi-Fi; allow `node` in the firewall) | Person 1 + Person 2 |
| B5 | Enable **Sign in with Apple** for `com.rishthefish.kavach` on team `L3ZM5X4NF8` | Person 1 (Apple team) |
| B / F | Approve publishing the new private schema to a **new** Maincloud database (not overwriting `kavach-qnc3a`) | Human |
| D | Enable **Push Notifications**, create an APNs key (`.p8`, Key ID, Team ID); deliver the `.p8` to Mac 2 out of band | Person 1 (Apple team) |
| E | Confirm in the Photon dashboard that project `kavach` has a **managed iMessage line** and its address (API returned 401 for line info) | Human |
| F | Choose the HTTPS hosting provider (supports long-running processes, HTTP/2 egress to APNs; allowed by hackathon rules) | Human |
