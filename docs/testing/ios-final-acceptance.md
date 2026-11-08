# Final iOS acceptance — 2026-11-08

| Gate | Observed status |
| --- | --- |
| Module 1 regression | Prior integration passed 177 backend, 34 host and simulator tests; see person1-module1 handoff |
| Current host foundations and final demo | PASS — unit: 43 discovered, 33 executed, 10 live-HTTP skipped, zero failures |
| Current iOS simulator | PASS — simulator: xcodebuild test exit 0, 29 unit tests and all 4 UI tests passed, including explicit final-demo workspace navigation |
| Signed baseline build | PASS — build: Xcode 27.2 generic iOS Debug, exit 0 |
| Physical baseline install/launch | PASS — physical iPhone: devicectl install and launch exit 0; not a visual/accessibility audit |
| Real NVIDIA from this phone | BLOCKED: documented Mac 2 hostname fails DNS resolution |
| Sign in / refresh / private reports | BLOCKED: canonical routes/schemas and Apple capability provisioning missing |
| Circles / authenticated SSE | BLOCKED: canonical domain contracts unavailable; SSE framing unit tests pass |
| APNs | BLOCKED: entitlements, canonical registration API and provider/device evidence missing |
| Messages / linking | BLOCKED: canonical agent/link contracts and verified managed line missing |
| Cross-user persistence | NOT RUN: authenticated services unavailable |
| Full VoiceOver / device large text | NOT RUN |
| Keychain lifecycle on device | NOT RUN: implementation compiled in host suite; session wiring pending |

Machine-local logs: `/tmp/kavach-final-ui-host.log`, `/tmp/kavach-final-device.log`, `/tmp/kavach-final-ui-simulator.log`. No token, provider key or private content is included in evidence.
