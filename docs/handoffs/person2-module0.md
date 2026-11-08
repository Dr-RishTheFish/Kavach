# Person 2 — Module 0 handoff

```text
Branch: feature/backend-ai (tracks origin/feature/backend-ai; based on feat/backend-setup 16f463c)

Git status before / after:
  Before: clean except untracked "untitled folder/" (the three hackathon briefs).
  After:  uncommitted Module 0 changes in backend/, agent/, spacetimedb/, shared/contracts/, docs/;
          root .env.example comment updated; "untitled folder/" left untouched and uncommitted.

Summary of changed files:
  backend/            NEW Fastify API: src/{app,server,config,contracts,version}.ts, src/routes/*,
                      src/risk/*, src/middleware/errors.ts, tests/*.test.ts, package.json + lockfile,
                      tsconfig*.json, vitest.config.ts, .env.example, .gitignore
  shared/contracts/   NEW analyze-request / risk-assessment / health / error .schema.json (draft 2020-12)
                      + examples/{analyze-request,analyze-response,analyze-error,health}.json
  spacetimedb/        REPLACED ScamShield stubs with a development_status table + set_development_status
                      reducer; removed schedules.ts, procedures.ts, reducers/; package.json scripts updated
  agent/              MOVED backend/photon-worker -> agent/photon-worker (still a scaffold); README.md;
                      regenerated module_bindings
  docs/               backend-setup.md, handoffs/person2-module0.md

HTTP dev command + observed port:
  cd backend && npm run dev   -> listening on http://127.0.0.1:3001 (lsof: bound to 127.0.0.1 only)

GET /health observed status + safe sample response:
  200 {"status":"ok","service":"kavach-api","version":"0.1.0","time":"2026-11-08T09:00:03.993Z"}

POST /api/v1/analyze observed status + schema check:
  200 for {"kind":"call","content":"My bank says to urgently wire money."}
      -> riskScore 92, riskLevel "critical", source "mock"; the response is validated against
         risk-assessment.schema.json at runtime and in tests.
  400 VALIDATION_ERROR for kind "unknown"; 400 INVALID_JSON for broken JSON; 413 for a 40 KB body.

Build command + actual exit result:
  cd backend && npm run typecheck && npm run build   -> exit 0
  cd spacetimedb && npx tsc --noEmit && spacetime build -> exit 0 ("Build finished successfully.")
  cd agent/photon-worker && npx tsc --noEmit          -> exit 0

Test command + actual exit result:
  cd backend && npm test   -> 8 files, 86 tests passed, exit 0 (offline, no credentials; was 76 before integration tests and the callback-rule regression fix)

SpacetimeDB CLI version:
  spacetimedb tool version 2.14.1; npm spacetimedb 2.14.1

SpacetimeDB local module verification result:
  VERIFIED — compiler/build
  VERIFIED — local publish + reducer/query (spacetime start; publish kavach-dev to --server local;
             set_development_status upserted the row; SELECT returned it; an invalid component was
             rejected by the reducer)
  NOT DONE (by design) — Maincloud kavach-qnc3a still has the earlier empty schema; not republished.

Secrets safe / .env ignored? YES
  git check-ignore confirms .env, .env.local, backend/.env and agent/.env are ignored. No secret values
  were printed or written. Logs contain no bodies, headers, query strings or error messages.

Contract v0 exact? YES, with these intentional, documented additions:
  1. 415 UNSUPPORTED_MEDIA_TYPE when the body is not application/json (not in the v0 table).
  2. 404 NOT_FOUND envelope for unknown routes (not in the v0 table).
  3. x-request-id response header (matches error.requestId).
  4. Unexpected request properties are rejected (the contract's "preferred" option).
  Response keys/types are exactly the v0 list. No reportId.

Remaining blockers:
  - The shared briefs are only in an untracked "untitled folder/". The brief expects them in
    docs/hackathon/ and START_HERE.md on main; neither exists yet. Committing them is a joint decision.
  - The initial monorepo has an empty root contracts/ folder; Module 0 uses shared/contracts/ as the brief
    says. Decide together whether to delete contracts/.
  - Root .env.example (from the earlier migration) uses NIM_API_KEY / MODEL_FAST names; backend/.env.example
    uses NVIDIA_API_KEY / NVIDIA_MODEL per the brief. Settle on one set of names in Module 1.
  - Root spacetime.json / spacetime.local.json point the CLI at Maincloud kavach-qnc3a and override db
    names in subfolders; use --no-config for local work (documented).

What Person 1 must know to integrate:
  - Canonical schemas: shared/contracts/*.schema.json. Fixtures: shared/contracts/examples/*.json.
    Swift decoding tests should load analyze-response.json and analyze-error.json from there.
  - Response fields: analysisId (UUID string), kind, riskScore (Int 0-100), riskLevel
    (low|guarded|high|critical), summary, signals [String], recommendedActions [String],
    source (mock|nvidia), requiresHumanReview (Bool), analyzedAt (ISO-8601 UTC with milliseconds,
    e.g. 2026-11-08T08:00:00.000Z — use ISO8601DateFormatter with .withFractionalSeconds).
  - source == "mock" must show DEMO / SIMULATED ASSESSMENT.
  - Errors: {"error":{"code","message","requestId"}}; handle unknown codes generically.
    Codes now: INVALID_JSON, VALIDATION_ERROR, PAYLOAD_TOO_LARGE, UNSUPPORTED_MEDIA_TYPE, NOT_FOUND,
    INTERNAL_ERROR (ANALYZER_UNAVAILABLE reserved for Module 1).
  - Send Content-Type: application/json. Unknown request keys are rejected with 400.
  - Base URL on the simulator: http://127.0.0.1:3001. A physical iPhone needs the deliberate LAN steps
    in docs/backend-setup.md plus an ATS development exception on the iOS side.

Suggested commit message:
  feat(backend): scaffold kavach API contracts and database module
```
