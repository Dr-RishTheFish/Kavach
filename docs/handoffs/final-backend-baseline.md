# Final backend — baseline audit (Person 2 / Mac 2)

**Date:** 2026-11-08 · **Spec:** `context_and_plan/KAVACH_FINAL_BUILD_MAC2_CLAUDE.md` (Edition 1.0, untracked)
**Plan:** `docs/superpowers/plans/2026-11-08-final-backend.md`

## Branch and baseline

| Item | Value |
|---|---|
| Working branch | `feature/final-backend` (local, not pushed; upstream deliberately unset so a push can't land on Person 1's branch) |
| Created from | `origin/feature/ios-module-1` @ **`e9dfbea`** `feat(ios): add manual scam analysis with mock and live backend modes` |
| History | Linear: `e9dfbea` (iOS M1) → `76579f8` (backend M1) → `f886076` (M0 integration tests) → `a292ed1` (M0 merge of `29c5898` backend + `6af7ef2` iOS) |
| `main` | Still `06cc2f5` (initial commit). **Modules 0/1 are not on `main`.** Open PRs before relying on `main`. |
| Working tree at audit | Clean except untracked `context_and_plan/` (shared briefs, not committed) |

## Merged features (in this baseline)

- **Module 0:** Fastify API (`GET /health`, `POST /api/v1/analyze`), contract v0.1.0 schemas + examples, deterministic mock analyzer, SpacetimeDB `development_status` table/reducer, Photon worker **stub**, integration tests/script.
- **Module 1 backend:** `NvidiaRiskAnalyzer` (fail-closed 503), `ANALYSIS_PROVIDER=mock|nvidia`, `NVIDIA_*` config incl. `NVIDIA_THINKING`, smoke script. Live `source:"nvidia"` verified with `nvidia/nemotron-3.5-lightning-30b-a3b`.
- **Module 1 iOS (Person 1):** manual analysis form, mock/live modes, safe errors, NVIDIA vs DEMO labels, Debug-only local-network plist, 20 host tests + 3 UI tests.

## Baseline verification (rerun on this branch, 2026-11-08)

`scripts/module0-integration.sh --with-simulator` → **exit 0**:

| Check | Result |
|---|---|
| Backend `npm test` / typecheck / build | **177/177** pass; exit 0; exit 0 |
| API smoke (health, valid mock, invalid kind, bad JSON) | 200 / 200 critical mock / 400 / 400 |
| Swift host tests incl. 10 live round trips | **34/34** pass |
| iOS simulator (iOS 26.4.1, iPhone 17 Pro) | 20 unit tests pass; **3/3 UI tests pass** (`testFourTabsAndDemoDisclosure`, `testDarkLargeTextLiveSetupError`, `testLiveMockResponseDisclosure`) |
| SpacetimeDB typecheck / build | pass |
| Privacy/security checks S1–S4 | pass |

**Fix made during the audit:** the first run skipped `testLiveMockResponseDisclosure` because the
script stopped the backend before the simulator stage, and the test needs the mock backend on
`127.0.0.1:3101`. `scripts/module0-integration.sh` now keeps the backend up through L5 (Person 1's
earlier pass relied on a leftover dev server on 3101).

**Not run:** local SpacetimeDB publish (L6). Port 3000 is held by a leftover `spacetime start` process
(pid 78045) from an earlier session, and stopping it was blocked by the local permission policy.
Stop it manually (`kill 78045`) before Phase B; the build/typecheck stages passed.

## Existing schemas and migrations

- `shared/contracts/`: `analyze-request`, `risk-assessment`, `health`, `error` (+ examples). **Frozen for the final build.**
- SpacetimeDB: one public, non-personal table `development_status`; no product tables; no migrations.
- Maincloud database `kavach-qnc3a` holds the earlier **empty** schema. It was never republished with the Module 0 module. Do not overwrite it without approval (plan proposes a new database).

## Credentials — presence only (no values read into docs or logs)

| Name | Where | State |
|---|---|---|
| `NVIDIA_API_KEY`, `NVIDIA_MODEL`, `NVIDIA_BASE_URL`, `NVIDIA_TIMEOUT_MS`, `NVIDIA_THINKING`, `ANALYSIS_PROVIDER`, `HOST` | `backend/.env` | set |
| `NIM_API_KEY`, `NIM_BASE_URL` | root `.env` | set (legacy names; `MODEL_FAST`/`MODEL_WRITER` empty) |
| `SPECTRUM_PROJECT_ID`, `SPECTRUM_PROJECT_SECRET` | root `.env` | set |
| `PHOTON_AGENT_USER_ID`, `PHOTON_WEBHOOK_SECRET`, `AGENT_SERVICE_TOKEN`, `SERVICE_KEY`, `SPACETIME_TOKEN` | root `.env` | empty |
| `SPACETIME_URI`, `SPACETIME_DB_NAME` | root `.env` | set |
| SpacetimeDB CLI login | `~/.config/spacetime` | logged in (identity `c200c1ad…`) |
| `SESSION_SIGNING_KEY`, `APPLE_CLIENT_ID`, `APNS_*`, `PHOTON_AGENT_ADDRESS`, `PUBLIC_BASE_URL` | — | **absent** (new for the final build) |
| APNs `.p8` | — | **absent** on Mac 2 (none in repo) |

## External provisioning state

| Gate | Finding | Status |
|---|---|---|
| Photon project | `cloud.getProject` with the project credentials → project **"kavach"** (credentials valid) | OK |
| Photon managed iMessage line | `cloud.getPlatforms` / `cloud.getImessageInfo` → **401** with project-secret auth (these endpoints need a different credential, probably the dashboard session) | **UNKNOWN**: check the Photon dashboard for an iMessage line and its address |
| Photon SDK | `spectrum-ts` / `@spectrum-ts/imessage` **12.15.0** installed (= latest); exports `Spectrum`, `cloud`, `imessage` | OK |
| Apple team / bundle | Xcode project: `DEVELOPMENT_TEAM = L3ZM5X4NF8`, bundle `com.rishthefish.kavach` | present |
| Sign in with Apple capability | No `.entitlements` file in `ios/` | **NOT ENABLED** |
| Push Notifications / `aps-environment` | No entitlements; no APNs key | **NOT ENABLED** |
| HTTPS hosting | No provider chosen; only `docker` installed on Mac 2 | **DECISION NEEDED** |
| Physical iPhone → Mac 2 → NVIDIA | Pending (both handoffs list it as not yet run) | **PENDING (Task A2)** |

## Contract decisions recorded before any change

1. The v0 analyze contract is frozen; new endpoints use new versioned schemas under `shared/contracts/v1/`.
2. New error codes are additive: `UNAUTHENTICATED` 401, `FORBIDDEN` 403, `IDEMPOTENCY_CONFLICT` 409, `INVITE_INVALID` 410, `RATE_LIMITED` 429, `STORE_UNAVAILABLE` 503. Cross-user access to private resources returns `404 NOT_FOUND`.
3. Saved-report scores come only from server-held analysis references (`verifiedByServer: true`); clients cannot submit scores.
4. Auth adds `POST /api/v1/auth/apple/nonce` (server-issued single-use nonce) and a clearly labelled `POST /api/v1/auth/test` fallback, disabled by default.

## What Mac 1 needs (in order)

1. **Now:** run Task A2 (physical iPhone, Live mode at `http://Chidatmas-MacBook-Pro.local:3001`, same Wi-Fi).
2. **Before Phase B ends:** enable Sign in with Apple for `com.rishthefish.kavach` (team `L3ZM5X4NF8`). The iOS flow sends the server-issued nonce (SHA-256 into `ASAuthorizationAppleIDRequest.nonce`) and posts `identityToken` + raw nonce. Store tokens in the Keychain.
3. **Before Phase D:** enable Push Notifications, create an APNs auth key, and send the `.p8` + Key ID + Team ID to Mac 2 out of band (never in chat or git).
4. Implement against `shared/contracts/v1/` schemas as each checkpoint lands (B, C, D, E).
