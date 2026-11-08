# Handoff: Person 2 → Person 1 — backend expectations for the final UI module

**From:** Person 2 / Mac 2 (backend, SpacetimeDB, Photon, APNs) · **To:** Person 1 / Mac 1 (SwiftUI)
**Date:** 2026-11-08 · **Backend branch:** `feature/final-backend` (from your `feature/ios-module-1` @ `e9dfbea`)
**Related:** `docs/handoffs/final-backend-baseline.md` (audit), `docs/superpowers/plans/2026-11-08-final-backend.md` (backend plan)

## How to read this

**Order agreed by the team:** the **final UI module is built first**. The backend final phases (B–F)
run afterwards and **will be refined to fit the UI you actually build**. So:

- **Section 2 is live and stable** (Modules 0–1). Build on it now.
- **Sections 3–8 are a DRAFT contract.** Use them to shape screens, flows and models. Build behind
  protocols with mock implementations (as you did for `AnalysisService`), because names and shapes may
  still change. The JSON Schemas under `shared/contracts/v1/` will become the source of truth once
  each backend phase lands. Until then, nothing in sections 3–8 exists on the server.
- **Section 9 lists what we need back from you.** Your answers decide the details of the backend phases.

---

## 1. Non-negotiables (both sides)

- `POST /api/v1/analyze` and its v0.1.0 request/response stay **exactly** as they are. `analysisId` is not a `reportId`.
- `source: "mock"` always shows DEMO; `"nvidia"` only after a real model call. No mock fallback after a live failure.
- No secrets in `ios/`: no NVIDIA, Photon, APNs, database or session-signing keys. The app only ever holds
  its own user's access/refresh tokens (Keychain) and its APNs device token.
- Save report and share-to-circle are **separate, explicit** user actions, both **off by default**.
- No claims of call/message interception, Recents buttons, call-screen overlays or reading personal threads.
  The call demo stays a labelled simulation.
- Scores are heuristics (0–24 low, 25–49 guarded, 50–74 high, 75–100 critical), never guarantees.

## 2. What works today (stable)

| Item | Detail |
|---|---|
| Start backend (Mac 2) | `cd backend && npm run dev`. `backend/.env` currently sets `HOST=0.0.0.0`, `PORT=3001`, `ANALYSIS_PROVIDER=nvidia` |
| Base URL | Simulator on Mac 2: `http://127.0.0.1:3001`. iPhone / Mac 1 (same Wi-Fi): `http://Chidatmas-MacBook-Pro.local:3001` (or `ipconfig getifaddr en0`) |
| Endpoints | `GET /health`, `POST /api/v1/analyze` (contract v0.1.0, `shared/contracts/*.schema.json`) |
| Live model | `nvidia/nemotron-3.5-lightning-30b-a3b`, typically 1–2 s, server timeout 15 s (keep the iOS timeout > 15 s) |
| Errors you'll see | 400 `VALIDATION_ERROR` / `INVALID_JSON`, 413, 415, 404, 500, **503 `ANALYZER_UNAVAILABLE`** (show the message + Retry) |
| Verified on this branch | backend 177/177, your Swift host 34/34, simulator 20 unit + **3/3 UI** (the integration script now keeps the backend up so `testLiveMockResponseDisclosure` really runs) |
| Still pending | **Physical iPhone → Mac 2 → NVIDIA** run (Task A2). Please do this first; see §10. |

## 3. Draft API v1 overview (not implemented yet)

All new routes are under `/api/v1`, JSON, and need `Authorization: Bearer <accessToken>` unless
marked *public*. Mutating calls that create things take an `Idempotency-Key: <uuid>` header. Generate one
per user action and **reuse it on retry** so a retried tap never creates duplicates.

| Area | Method + route | UI it supports |
|---|---|---|
| Auth | `POST /auth/apple/nonce` *(public)* → `{ nonce, expiresAt }` | Sign in with Apple button |
| | `POST /auth/apple` *(public)* `{ identityToken, nonce, displayName? }` → session | |
| | `POST /auth/test` *(public, dev-only)* `{ username, password }` → session | "Test account" sign-in (clearly labelled) |
| | `POST /auth/refresh` *(public)* `{ refreshToken }` → session | silent token refresh |
| | `POST /auth/logout` | Sign out |
| Profile | `GET /me` | Settings / account |
| Reports | `POST /reports` · `GET /reports?cursor=&limit=` · `GET /reports/{reportId}` · `DELETE /reports/{reportId}` | Save result, My reports list/detail, delete |
| Circles | `POST /circles` · `GET /circles` · `GET /circles/{circleId}` | Create circle, circle list/detail |
| | `POST /circles/{circleId}/invites` → `{ inviteCode, expiresAt }` · `POST /circle-invites/redeem` `{ inviteCode }` | Invite / join |
| | `DELETE /circles/{circleId}/members/me` · `DELETE /circles/{circleId}/members/{memberId}` | Leave / remove member |
| | `POST /circles/{circleId}/shares` · `GET /circles/{circleId}/alerts?cursor=&limit=` | Share report, alert feed |
| Live | `GET /events` (SSE) | Live alert updates while foregrounded |
| Push | `POST /devices` · `DELETE /devices/{deviceId}` | Notification opt-in / opt-out |
| Agent | `GET /agent` · `POST /agent/link/start` · `POST /agent/link/confirm` | "Talk to Kavach in Messages" + account linking |

Planned **new error codes** (additive): `UNAUTHENTICATED` 401, `FORBIDDEN` 403, `IDEMPOTENCY_CONFLICT`
409, `INVITE_INVALID` 410, `RATE_LIMITED` 429, `STORE_UNAVAILABLE` 503. Another user's private resource
returns **404** (it's hidden, not "forbidden"). Keep handling unknown codes generically.

## 4. Accounts and sessions (draft)

**Sign in with Apple (primary)**
1. App calls `POST /auth/apple/nonce` and gets a single-use `nonce` (valid ~5 min).
2. App sets `ASAuthorizationAppleIDRequest.nonce = SHA256(nonce)` (hex), requests `.fullName` optionally.
3. On success, app posts `{ identityToken: <JWT string>, nonce: <raw nonce>, displayName? }` to `POST /auth/apple`.
4. Server verifies Apple's signature, issuer, audience (`com.rishthefish.kavach`), expiry and the nonce
   (single use), then returns:

```json
{
  "accessToken": "<short-lived, ~15 min>",
  "accessTokenExpiresAt": "2026-11-08T12:15:00.000Z",
  "refreshToken": "<opaque, ~30 days, rotates on every refresh>",
  "refreshTokenExpiresAt": "2026-12-08T12:00:00.000Z",
  "user": { "userId": "<uuid>", "displayName": "Asha", "authMethod": "apple", "createdAt": "…" }
}
```

**Token handling the app must do**
- Store both tokens in the **Keychain** (not UserDefaults). Never log them.
- On any `401 UNAUTHENTICATED`, call `POST /auth/refresh` **once**, store the **new** pair (the old refresh
  token is dead), and retry the original request once. If refresh fails, sign the user out locally.
- Serialize refreshes (one in flight). Reusing an old refresh token revokes the whole session by design.
- Sign out: `DELETE /devices/{deviceId}` (if registered), then `POST /auth/logout`, then clear the Keychain.

**Test-account fallback:** if the Sign in with Apple capability isn't ready, the server can enable
`POST /auth/test` with server-configured demo accounts. The UI must label this **"Test account"** and
show `authMethod: "test"`. Never present it as Apple login.

**UI states to design:** signed out (analysis still usable anonymously; save/circles need sign-in),
signing in, signed in, session expired → re-sign-in, account screen with display name and sign-out.

## 5. Reports (draft)

**Save** (only after the user taps *Save report*, with a clear consent line):

```http
POST /api/v1/reports
Authorization: Bearer <accessToken>
Idempotency-Key: <uuid per tap>

{ "consent": true, "kind": "call", "analysisId": "<from the analyze result>",
  "description": "optional text the user chooses to keep", "notes": "optional" }
```

- **Do not send scores.** The server attaches the assessment itself if `analysisId` came from it within
  the last ~60 minutes. Otherwise the report is saved with `assessment: null`. Show that honestly
  ("Saved without an assessment").
- `description` is optional and sensitive. Default to **not** including the original text; let the user
  opt in (toggle or editable field).

**Report shape:**

```json
{
  "reportId": "<uuid>", "analysisId": "<uuid>|null", "kind": "call",
  "description": "…|null", "notes": "…|null",
  "assessment": { "riskScore": 85, "riskLevel": "critical", "source": "nvidia", "summary": "…",
                  "signals": ["…"], "recommendedActions": ["…"], "verifiedByServer": true } ,
  "createdAt": "2026-11-08T12:00:00.000Z"
}
```

**List:** `GET /reports?limit=20&cursor=<nextCursor>` → `{ "items": [Report], "nextCursor": "…"|null }`
(newest first, max 50 per page). **Delete** hides the report and stops future sharing; it's idempotent.

**UI to design:** Save button + consent copy on the result screen, My reports list (pagination, empty
state, pull to refresh), report detail, delete with confirmation.

## 6. Trusted circles and alerts (draft)

**Policies the UI must reflect:** invite-only, no public discovery, no contacts upload. Owner/admin
invites and removes; anyone can leave. Invites expire after ~15 minutes with limited uses. Sharing is
explicit, per report, per circle; revoking stops future visibility, but **already delivered
notifications and screenshots can't be recalled** (say so).

- **Invite:** `POST /circles/{id}/invites` → `{ "inviteCode": "K7Q-4PZ-9XM", "expiresAt": "…" }`. Show the
  code with a share sheet and a countdown. The code is a secret: don't log it or put it in analytics.
- **Join:** user enters or pastes the code → `POST /circle-invites/redeem`. Errors: `410 INVITE_INVALID`
  (expired, used or revoked).
- **Share:** a separate confirmation sheet naming the circle and showing **exactly** what members will see:

```http
POST /api/v1/circles/{circleId}/shares
Idempotency-Key: <uuid per confirm tap>

{ "reportId": "<uuid>", "shareConsent": true,
  "preview": "Possible bank impersonation. Do not share verification codes." }
```

  Members see only the **sanitized preview**, severity and time, **never** the original text, phone
  number or codes. Prefill the preview from the assessment summary and let the user edit it
  (max ~140 chars).
- **Alerts feed:** `GET /circles/{id}/alerts?cursor=&limit=` is the source of truth. Load it on open and
  after reconnecting.

## 7. Live updates (SSE) and push (draft)

**SSE** `GET /api/v1/events` with `Authorization: Bearer …` and `Accept: text/event-stream`. Use a
`URLSession` streaming task (`bytes(for:)`). Don't put tokens in the URL.

```text
id: 42
event: circle.alert.created
data: {"alertId":"<uuid>","circleId":"<uuid>","severity":"critical","createdAt":"2026-11-08T12:00:00.000Z"}

```

- Event types planned: `circle.alert.created`, `circle.alert.revoked`, `circle.membership.changed`,
  `circle.membership.revoked` (you were removed: drop that circle's cached data), plus `: heartbeat`
  comments about every 15 s.
- Reconnect with `Last-Event-ID: <last id>` after a drop (exponential backoff). If the server can't replay
  that far, re-fetch `GET /alerts`. Connect only while foregrounded; on `401`, refresh and reconnect.

**Push (APNs)**
- Requires the **Push Notifications** capability and a signed build on a **physical iPhone**.
- Ask permission with a clear rationale only when the user joins or creates a circle (not at launch).
  Then `registerForRemoteNotifications()`.
- Send the token: `POST /devices` `{ "deviceToken": "<hex>", "environment": "development"|"production",
  "bundleId": "com.rishthefish.kavach", "notificationsEnabled": true }` → `{ "deviceId": "<uuid>" }`. Re-send
  when the token changes; `DELETE /devices/{deviceId}` on sign-out or opt-out.
- Payload you'll receive (no private text in it):

```json
{ "aps": { "alert": { "title": "Kavach safety alert",
  "body": "A trusted-circle member shared a high-risk scam report." }, "sound": "default" },
  "type": "circle_alert", "alertId": "<uuid>", "circleId": "<uuid>" }
```

- Tap → open that circle's alert (deep link by `alertId`/`circleId`), then fetch it from the API.
  Treat push as **best effort**; the stored feed is authoritative. Show an honest state if
  notifications are denied.

## 8. Photon iMessage agent (draft)

- `GET /agent` → `{ "available": true, "address": "<managed iMessage address>" }` or `{ "available": false }`.
  Show "Talk to Kavach in Messages" only when available; open Messages with `sms:<address>` (or the
  documented iMessage URL). **Never hard-code the address.**
- **Account linking** (needed before the agent can save reports for the user):
  1. In the app (signed in), the user taps *Link Messages* → `POST /agent/link/start` → `{ "code": "482913", "expiresAt": "…" }` (~10 min, single use).
  2. The user sends that code to the Kavach agent in Messages.
  3. The app shows the pending link (e.g. "Messages conversation ending …1234, linked just now?") and the
     user confirms → `POST /agent/link/confirm`. Show linked state and an *Unlink* action.
- Without linking, the agent gives general safety guidance only. Saving a report and sharing to a circle
  from Messages each need separate confirmation in the conversation.

## 9. Decisions we need from you (these shape the backend phases)

Please answer in your final-UI handoff (`docs/handoffs/person1-final.md` or similar):

1. **Sign-in:** will you ship Sign in with Apple, the test-account fallback, or both? Is anonymous
   analysis (no account) still allowed before sign-in?
2. **Navigation/deep links:** URL scheme or universal-link paths you'll handle (e.g. `kavach://circle/{id}/alert/{alertId}`).
3. **Report save UX:** do you keep the original description by default (we recommend not), and do you
   want `notes`?
4. **Share preview:** user-edited, auto-generated from the summary, or chosen from fixed templates? Max length?
5. **Circle features in v1:** multiple circles per user or one? Roles needed (owner/admin/member)? Display
   names shown to members?
6. **Live updates:** is SSE while foregrounded enough, or do you need anything else (e.g. badge counts)?
7. **Push:** when you request permission; which build/environment (`development` for the demo?); the exact
   bundle ID in the signed build.
8. **Agent linking UX:** is the code-in-Messages + confirm-in-app flow acceptable on your screens?
9. **Anything in your UI that needs data not listed here.** Tell us before we build, not after.

## 10. Apple / device prerequisites (Person 1's team `L3ZM5X4NF8`)

| When | Action | Why |
|---|---|---|
| Now | Run the physical iPhone in Live mode against Mac 2 (same Wi-Fi; Mac 2 may show a firewall prompt for `node`) | Closes Module 1 (Task A2) |
| Before backend Phase B | Enable **Sign in with Apple** for `com.rishthefish.kavach` | Real identity tokens |
| Before backend Phase D | Enable **Push Notifications**; create an **APNs Auth Key** (.p8) and note **Key ID** + **Team ID** | Server-side push |
| Before backend Phase D | Deliver the `.p8` + IDs to Mac 2 **out of band** (AirDrop / password manager). **Never** in git, chat or screenshots | Secret stays on the server |
| Before backend Phase F | Confirm the off-LAN plan: the final build should call an **HTTPS** URL, so Release needs no ATS exception | Demo on mobile data |

## 11. Suggested build approach for the final UI

- Keep the pattern you used for `AnalysisService`: a protocol per area (`AuthService`, `ReportService`,
  `CircleService`, `EventStream`, `DeviceRegistry`, `AgentService`), each with a **mock** implementation
  driving the UI and tests now and an HTTP implementation added once the backend phase lands.
- Put request/response models in one place so they can be checked against `shared/contracts/v1/`
  fixtures when they arrive (same fixture-decoding tests as Module 0).
- Keep every new flow's "not connected yet" state honest in the UI (like DEMO), so nothing looks live
  before it is.
- Tests worth adding now: token refresh-once-then-sign-out, idempotency key reuse on retry, SSE
  reconnect with `Last-Event-ID`, push-denied state, share confirmation shows the exact preview.

## 12. Next sync points

1. You finish the final UI on mocks and answer §9 → **Person 2 refines the backend plan** (phases B–F) to
   match, publishes `shared/contracts/v1/` schemas + curl fixtures per phase.
2. At each backend checkpoint (auth, circles + feed, push, agent) you swap that area's mock for HTTP and run
   the shared fixture tests.
3. Final two-user, two-device demo run (spec §16), recorded in `docs/testing/final-e2e-matrix.md`.
