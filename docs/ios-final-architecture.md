# Final iOS architecture

The current executable app retains Module 1's AnalysisService, AnalysisViewModel and shared AppSettings. Requests are explicit user actions. Mock responses remain visibly simulated. The existing four tabs are preserved.

`Core/FinalFoundation.swift` adds reusable primitives: opaque Keychain session storage scoped by bundle ID/account with WhenUnlockedThisDeviceOnly accessibility and no synchronization, Security-generated nonce and CryptoKit SHA256, explicit feature availability, and bounded incremental SSE framing. These are foundations, not connected account or event features.

Person 2's UI-first handoff at `85ee3e2` requests protocol-backed demos before backend phases. `FinalDemoStore` and the final workspace provide explicitly labeled, memory-only account/report/circle flows. Domain types are not Codable wire contracts. Demo identities never impersonate Apple authentication, and notification/agent availability never fabricates provider delivery.

Pending canonical backend schemas, session/reports/circles/device/agent HTTP adapters are intentionally not implemented as guessed JSON. The next integration layer must own single-flight refresh, retry once after 401, clear private state on logout/account change, and refuse credential transport over plaintext HTTP. Reports and sharing remain separate consent actions. Event payload decoding, replay cursor and registration semantics must follow Person 2's versioned fixtures.

One main-actor coordinator will own session/UI lifecycle; one stream owner will cancel on background/logout and perform authenticated catch-up on foreground. APNs is a navigation hint, never authorization or a replacement for persisted alerts. Messages composer dismissal is never proof of delivery.
