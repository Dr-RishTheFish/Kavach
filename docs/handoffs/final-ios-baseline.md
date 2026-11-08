# Final iOS baseline — 2026-11-08

Approved working branch: `feature/final-ios`, created from published Module 1 commit `e9dfbea9bab74ede78dae5b127e5c32e2d393faa`. This includes Person 2 backend commit `76579f87e4e6f3fcdfe2403808f00b5ef782ef26`. Tracked tree was clean; unrelated untracked `.claude/settings.json` is preserved.

Xcode 27.2 (27B52), Swift 6.4.2, iOS SDK 27.2; app minimum iOS 17, Swift 5 language mode. Bundle ID `com.rishthefish.kavach`. An Apple development team is configured in both app build configurations; provisioning eligibility has not yet been proven. No app entitlement file exists, and Sign in with Apple / APNs capabilities are not configured.

A physical iPhone 18 Pro Max is connected. Installed simulator runtimes include iOS 17.0, 17.5 and 18.0. Device OS and valid signed installation remain to be verified; presence in device discovery is not proof of successful launch.

Module 1 provides manual four-kind analysis, validation, cancellation/retry, source-aware results and explicit offline/live configuration. The Circle tab remains demo-only. Reports, auth, events, remote push and managed Messages linking are absent.

After fetching origin, no final-backend branch or final schemas were published. `shared/contracts/` contains only analysis, health and error contracts and fixtures. `docs/contracts/ios-api-v1.md` is absent. The current backend has analysis and health; authenticated `/me`, reports, circles, devices, events and agent routes are not implemented. Their brief examples are provisional and must not become invented wire DTOs.

No public HTTPS endpoint has been supplied. Prior Mac 2 handoff records a development `.local` endpoint and locally verified NVIDIA inference. Cross-device NVIDIA, actual APNs and actual managed iMessage remain unverified. Apple capabilities, two verified identities, public HTTPS and Photon provisioning require external configuration.

References: `docs/handoffs/person1-module1.md` for Module 1 test evidence; `docs/backend-module1-handoff.md` for backend model and startup; `docs/ios-setup.md` for simulator/device run instructions. Full final specs are machine-local in Downloads, not executable API contracts.
