# Module 0 — integrated test plan (iOS + backend)

Branch: `feature/module-0-integration` = `feature/backend-ai` (29c5898) +
`feature/ios-app` (6af7ef2), merged in a292ed1, plus these integration tests.

Sources of the requirements: `PROJECT_CONTEXT.md` §7–8, `API_CONTRACT_V0.md` §2–8,
`MODULE_0_PERSON_2_CLAUDE.md` §C8/E, `docs/handoffs/person1-module0.md`.

Module 0 acceptance (`PROJECT_CONTEXT.md` §5): *both sides build and test independently, and the mock
payloads agree*. Module 1 readiness (`API_CONTRACT_V0.md` §10): *the HTTP mock response round-trips
into Swift models*. This plan tests both.

## How to run everything

```bash
scripts/module0-integration.sh                    # backend + SpacetimeDB + Swift host + live round trip
scripts/module0-integration.sh --with-simulator   # also xcodebuild test on an iOS simulator
```

The script starts the backend on `127.0.0.1:3101`, so it won't clash with a dev server on 3001,
and always stops it on exit.

## Test levels

| Level | What it proves | Where | Runs offline |
|---|---|---|---|
| L1 Backend unit/HTTP | Validation, mapping, errors, log redaction, schema conformance | `backend/tests/*.test.ts` (Vitest, `fastify.inject`) | yes |
| L2 Backend real socket | Same contract over a real TCP listener, loopback bind | `backend/tests/listen.test.ts` | yes (loopback) |
| L3 Contract fixture parity | iOS fixture == canonical fixture; Swift decodes **every** shared example | `backend/tests/crossPlatform.test.ts`, `ios/KavachTests/SharedContractFixtureTests.swift` | yes |
| L4 Live Swift ↔ backend | Real `HTTPAnalysisService` → real backend → Swift models | `ios/KavachTests/LiveBackendIntegrationTests.swift` (skipped unless `KAVACH_LIVE_API_URL` is set) | loopback |
| L5 iOS app | Person 1's unit + UI tests on a simulator | `xcodebuild test` | yes |
| L6 SpacetimeDB | Module build; local publish + reducer + query | `spacetimedb/` + local `spacetime start` | loopback |
| M  Manual | Physical iPhone, dark mode, Dynamic Type, demo labels | checklist below | — |

## Test matrix

### Contract and data shape

| ID | Requirement | Test | Level |
|---|---|---|---|
| C1 | Response keys/types exactly v0, no `reportId` | backend `analyze.test.ts`; Swift decode of live responses | L1, L4 |
| C2 | `riskLevel` derived from score, 0/24/25/49/50/74/75/100 boundaries | backend `classify.test.ts`; Swift `ContractTests.testRiskBoundaries` | L1, L5 |
| C3 | iOS copy of the fixture equals `shared/contracts/examples/analyze-response.json` | `crossPlatform.test.ts` (deep-equal), Swift `testIOSFixtureMatchesCanonicalFixture` | L3 |
| C4 | Swift decodes the canonical response, error and request examples | `SharedContractFixtureTests` | L3 |
| C5 | Swift-encoded requests are accepted by the backend schema (optional fields omitted when nil) | live tests send full and minimal requests | L4 |
| C6 | Backend timestamps (`.SSSZ`) decode in Swift and are current | `testLiveScenariosMatchIOSMockLevels` checks `analyzedAt` ±5 min | L4 |
| C7 | `analysisId` is a UUID from the server, fresh per call | live test parses `UUID(uuidString:)` and compares two calls | L4 |
| C8 | `kind` echoed; Swift rejects a mismatched kind | live tests + Person 1's stub tests | L4, L5 |

### Mock parity (both sides must agree)

| ID | Scenario (iOS `DemoScenario`) | iOS score / level | Backend score / level |
|---|---|---|---|
| P1 | bank — "I am from your bank, transfer money in ten minutes" | 92 critical | 92 critical |
| P2 | code — "Tell me the code we just texted you" | 88 critical | 95 critical |
| P3 | delivery — "Delivery failed, pay a small fee at this link" | 64 high | 65 high |
| P4 | unknownContact — "An unknown number asked me to call them back" | 36 guarded | 35 guarded |
| P5 | lunch — "A friend confirmed our lunch plans" | 12 low | 10 low |
| P6 | unrecognized text | guarded, `requiresHumanReview` true | 40 guarded, `requiresHumanReview` true |

Scores may differ (the contract allows it). **Levels and `source: "mock"` must match.** Tested live by
`testLiveScenariosMatchIOSMockLevels` and `testUnrecognizedTextIsGuardedAndFlaggedOnBothSides`.

### Errors over the real wire

| ID | Input sent by Swift | Expected | Test |
|---|---|---|---|
| E1 | blank content `"   "` | `.api(400, VALIDATION_ERROR)`, requestId present, message free of input | `testBlankContentMapsToValidationError` |
| E2 | phone `555-0123` | `.api(400, VALIDATION_ERROR)` | `testInvalidPhoneMapsToValidationError` |
| E3 | content 5000 chars / 5001 chars | 200 / `.api(400, VALIDATION_ERROR)` | `testContentLengthBoundary` |
| E4 | content 40 000 chars | `.api(413, PAYLOAD_TOO_LARGE)` | `testOversizedBodyMapsToPayloadTooLarge` |
| E5 | server not running | throws `URLError`; **no silent mock fallback** | `testUnreachableServerThrowsInsteadOfFallingBack` |
| E6 | invalid JSON, wrong content type, unknown route | 400 / 415 / 404 envelopes | backend `analyze.test.ts` (Swift can't produce these) |
| E7 | analyzer bug (bad score/source/missing field, exception) | 500 `INTERNAL_ERROR`, no stack | backend `analyze.test.ts` |

### Privacy, safety and configuration

| ID | Requirement | Test |
|---|---|---|
| S1 | No request content, phone, context, auth header or query string in backend logs | `analyze.test.ts › logging redaction`; the script greps the live server log for the submitted marker text |
| S2 | Backend binds loopback by default | `listen.test.ts` checks the bound address; the script checks `lsof` |
| S3 | No secrets in the iOS project | the script scans `ios/` for key-like strings and `NVIDIA`/`SPECTRUM` env names in Swift sources |
| S4 | `.env` files ignored | the script runs `git check-ignore` on `.env`, `backend/.env`, `ios/Configuration/Local.xcconfig` |
| S5 | `ANALYSIS_PROVIDER=nvidia` refused (no fake live result) | `config.test.ts` |
| S6 | Unicode handling (emoji, non-Latin) | `testUnicodeContentRoundTrips` + backend code-point length test |

## Manual checklist (not automatable here)

| ID | Check | Owner | Expected |
|---|---|---|---|
| M1 | Run the app on the physical demo iPhone (signing team, Developer Mode) | Person 1 | Four tabs load offline |
| M2 | Every mock score card shows **DEMO · Simulated assessment** | Person 1 | Visible on Home and Analyze |
| M3 | Low-risk card never reads as "safe" | Person 1 | Copy says it is not a guarantee |
| M4 | Dark mode and accessibility Dynamic Type sizes | Person 1 | Readable, no clipping |
| M5 | Settings → saving the dev API URL makes **no** network call | Person 1 | Confirm with backend log: no requests arrive |
| M6 | Circle tab shows only explicit preview data, no sharing | Person 1 | No network, no contacts prompt |
| M7 | Backend `npm run dev` + curl the three contract examples by hand | Person 2 | 200 / 200 / 400 as documented |

## Not tested in Module 0 (by design)

Live NVIDIA, Photon/iMessage, reports, circles, auth, LAN access from a physical iPhone (needs an
ATS exception and a deliberate `HOST` change, Module 1), and Maincloud deploys.

## Known integration notes found while designing these tests

1. iOS `DemoScenario` assessments use ids like `demo-bank`, not UUIDs. That's fine for local-only mock
   data, but the backend schema requires `format: uuid`. Don't send these ids back to the server.
2. Person 1's Xcode project was verified on Xcode 27.2. This Mac has Xcode 26.4.1, so L5 also tests
   that the project opens with the older Xcode.
3. The new Swift test files sit under `ios/KavachTests/` but are **not** added to
   `Kavach.xcodeproj`, so they run via `swift test` (SwiftPM) only. Adding them to the Xcode target is
   Person 1's call.

## Results — 2026-11-08, Mac 2 (uncommitted integration branch)

Command: `scripts/module0-integration.sh --with-spacetime --with-simulator` → exit 0.

| Level | Result |
|---|---|
| L1–L3 backend | PASS — 8 files, 86 Vitest tests (unit, inject, real socket, iOS fixture parity) |
| L3–L4 Swift | PASS — 26 XCTest tests: Person 1's 12 + 4 shared-fixture + 10 live round-trip against `127.0.0.1:3101` |
| API smoke | PASS — /health 200, valid 200 critical mock, invalid kind 400, bad JSON 400 |
| S1–S4 | PASS — no submitted text in logs, loopback bind, no secrets in `ios/`, env files ignored |
| L6 SpacetimeDB | PASS — typecheck, build, local publish, reducer write, query |
| L5 simulator | **NOT VERIFIED** — this Mac has Xcode 26.4.1 but only the iOS 26.2 simulator runtime, so `xcodebuild` reports "iOS 26.4 is not installed". Install it via Xcode > Settings > Components (or `xcodebuild -downloadPlatform iOS`) and rerun. Person 1 reported L5 passing on their Mac (Xcode 27.2). |
| Manual M1–M7 | Not run |

Test-the-tests: temporarily editing the canonical `analyze-response.json` made
`testIOSFixtureMatchesCanonicalFixture` fail. The file was then restored byte-for-byte.

### Defect found by integration and fixed

**I-1 (backend mock):** iOS's own "unrecognized text" sample (`"Unrecognized synthetic text…"`) was
classified by the backend as an *unsolicited callback* (score 35, `requiresHumanReview: false`),
because the rule matched the bare word "unrecognized". The levels matched by coincidence (both
guarded), but the review flag and explanation disagreed. Found by
`testUnrecognizedTextIsGuardedAndFlaggedOnBothSides`. Fixed in `backend/src/risk/MockRiskAnalyzer.ts`:
the rule now needs an unfamiliar *number/caller/contact/sender/phone*, "no caller id", or a callback
request. Regression tests were added first and seen failing (`mockAnalyzer.test.ts`); iOS needed no change.
