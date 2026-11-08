# Final iOS implementation and verification plan

Preserve the approved Module 1 baseline and existing signing settings. Work only in iOS and iOS documentation. Person 2 owns canonical schemas and backend behavior. Do not ship guessed auth, report, circle, device or linking JSON.

1. Audit baseline, signed build and reachable NVIDIA health. Run existing regression checks. Record external failures separately from code failures.
2. Implement contract-independent Keychain storage, cryptographic nonce generation, explicit feature availability and bounded incremental SSE framing. Test malformed/partial frames, UTF-8, storage errors and nonce behavior.
3. When auth fixtures arrive, implement exact token exchange and single-flight refresh, session lifecycle, Keychain persistence, revocation and private UI clearing. Verify concurrent 401 and two-user isolation.
4. When report/circle fixtures arrive, implement private report CRUD, explicit save/share consent, invitation membership and idempotent sharing. Verify pagination, retries and account separation.
5. Connect SSE framing to documented event types, cursor semantics and authenticated transport. Add lifecycle cancellation, deduplication and REST catch-up.
6. Add contextual notification permission, real APNs callbacks and registration through canonical device schema; fetch authorized alert details on taps. Test device-before-login and logout races. Require physical delivery evidence.
7. Add user-initiated Messages composer from the verified agent address, exact server linking handshake and separate report/share consent. Require actual managed-line reply evidence.
8. Complete device accessibility checks, regression tests, code review and required setup/acceptance/handoff documents. Optional simulated-call flow follows core work and must be labeled simulated.

Each phase must distinguish unit/simulator results from actual backend/database/provider/device evidence. Missing schemas block wire integration but do not justify a mocked live success. Missing provider provisioning remains BLOCKED until observed working. User will coordinate and merge Person 2's work; no automatic main merge or force push.
