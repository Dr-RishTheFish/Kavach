# Person 1 final-build progress handoff

## Person 2 handoff alignment

Pulled `feature/final-backend` at `85ee3e2` with `--ff-only`. Its `person2-to-person1-final-ui.md` explicitly says final phases are not yet implemented and requests UI first on mocks. No `shared/contracts/v1/` schemas exist. Final UI remains explicitly demo-only; these are domain models, not a frozen wire schema.

Answers to Person 2 section 9:

1. Ship Apple sign-in when provisioned, plus clearly labeled backend test accounts only when enabled by the server. Anonymous analysis stays available. Demo accounts are separate fictional in-memory identities.
2. Proposed route `kavach://circle/{circleId}/alert/{alertId}`; do not trust route IDs as authorization. Fetch before displaying. URL registration and route activation await canonical IDs/events.
3. Original description is excluded by default. Offer editable optional description and notes with explicit save consent. Never send scores from the client as verified evidence.
4. Share preview is editable, max 140 Unicode code points, prefilled from summary only; consent defaults off. Reuse one UUID per intended action across retries.
5. Multiple circles; owner/admin/member roles. Server-authoritative display names, no contact uploads. Owner/admin invites/removes; last owner must transfer ownership or close circle per final backend policy.
6. Foreground SSE with authenticated catch-up is sufficient. Badge counts are optional and must be server-derived.
7. Ask for notification permission after explicit join/create context, not launch. Demo target uses development APNs, bundle `com.rishthefish.kavach`. Apple capability/provider proof remains pending.
8. Code-in-Messages then authenticated in-app confirmation is acceptable. Confirmation must follow verified provider conversation proof; expose unlink/revoke semantics in the final contract.
9. Needed unresolved shapes: circle/member/list/share responses, invitation redeem result, alert pagination, agent link status/unlink endpoint, event replay reset behavior, Apple nonce response encoding, and device deletion/logout behavior. Publish fixtures before HTTP adapters are activated.

Branch `feature/final-ios`, original baseline `e9dfbea9bab74ede78dae5b127e5c32e2d393faa`, current HEAD `85ee3e2` after pulling Person 2's UI handoff. Final-build additions are local and uncommitted. Existing `.claude/settings.json` is preserved. No backend implementation, shared schema or partner branch was modified.

Implemented foundations: opaque Keychain credential store, secure Apple nonce generation/hash, feature-availability type, bounded incremental SSE framing, focused tests and Xcode source/test registration. Added the final UI workspace requested by Person 2: fictional account switching, session-only private reports with save/delete consent, multiple circles, expiring single-use invitations, owner member removal, leave, sanitized alert feed, and separate consented idempotent sharing. Reports are entered from analysis results; the workspace is discoverable from Settings and Circle. Every flow is explicitly DEMO and in memory. Messages and push show their actual unavailable state. These primitives are not yet wired to live account or circle services. See `docs/ios-final-architecture.md` and `docs/ios-final-plan.md` for integration boundaries.

Baseline signed iPhone build, physical install and launch passed. Final host suite passed 33 executed tests with 10 live HTTP tests skipped. The final iOS simulator run passed 29 unit tests and all four UI tests. The documented Mac 2 hostname fails DNS resolution. See `docs/testing/ios-final-acceptance.md` for truthful gate statuses and machine-local logs.

Required next dependency: Person 2's immutable implemented final-backend commit with `docs/contracts/ios-api-v1.md` and versioned auth/report/circle/event/device/agent schemas and fixtures. The available `85ee3e2` commit is a planning/UI handoff only. Do not invent wire payloads from illustrative prose. The complete connected product is not finished: real authentication, refresh lifecycle, report/circle persistence, event transport, APNs registration and Messages linking remain to implement against those contracts. The UI-first demo is ready for Person 2 to refine those schemas.

Judges can run the existing Module 1 Analyze demo with explicit DEMO labels. Do not present that as final reports, APNs or Photon delivery. Real-provider acceptance needs reachable HTTPS, Apple capabilities, two identities, actual APNs delivery and an observed managed iMessage reply. User intends to coordinate Person 2 integration; no automatic merge or force push is authorized.
