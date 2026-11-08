# Person 1 — iOS Module 1 handoff

## Delivery and ownership

Branch: `feature/ios-module-1`. HEAD: `76579f8` (Person 2's committed NVIDIA backend), fast-forwarded from `f8860760c396437600061c90e7c12ae616d25b14`. Person 1's iOS Module 1 changes are local and uncommitted; the branch has not been pushed and nothing was merged into main.

Before editing, origin was fetched and the integration branch matched its remote. Both accepted Module 0 commits (`6af7ef2`, `29c5898`) were ancestors. The tracked working tree was clean. Preexisting untracked `.claude/settings.json` was preserved. Person 2's `feature/backend-module1` was later pulled with `--ff-only`; its committed backend and error-schema changes remain intact. Person 1 did not edit `backend/`, `agent/`, `spacetimedb/` or `shared/contracts/`.

Changed/new files:

- `ios/Kavach/Core/AnalysisFlow.swift`: configuration, draft validation, safe errors and request state.
- `ios/Kavach/Core/DesignSystem.swift`: response-source labels and additional-verification wording.
- `ios/Kavach/Features/AnalyzeView.swift`: manual form, submission/cancellation and results.
- `ios/Kavach/Features/SettingsView.swift`: offline/live selection and endpoint editing.
- `ios/Kavach/Features/HomeView.swift`: truthful manual-analysis/future-feature copy.
- `ios/Kavach/KavachApp.swift`: shared nonsecret settings.
- `ios/Configuration/Info-Debug.plist`, `Info-Release.plist`: development-only ATS configuration and local-network explanation.
- `ios/Kavach.xcodeproj/project.pbxproj`, `ios/scripts/generate-project.rb`: source/config registration.
- `ios/KavachTests/AnalysisFlowTests.swift`, `ios/KavachUITests/NavigationTests.swift`: lifecycle, validation, persistence and UI coverage.
- `docs/ios-module1-plan.md`, `docs/ios-setup.md`, this handoff: inventory, decisions and reproduction.

## Compatibility and behavior

Module 0 already supplied the four tabs, shared design system, validated DTOs, HTTP/mock services and host/simulator tests. Module 1 preserves those boundaries. Contract v0.1.0 and shared fixtures match Person 2's backend at `76579f8`; its error-schema description changed without changing keys, types, or wire semantics.

The main-actor view model owns idle → validating → loading → success/failure state. Draft edits, cancellation, leaving Analyze and service/address changes invalidate pending work. Generation tokens prevent a cancellation-ignoring old response from overwriting a newer result. A failed request retains text and allows retry. Services are resolved only at explicit submission; saving settings and selecting examples do not submit.

Offline mock remains the default. Only mode and address persist in UserDefaults. Empty optional fields and hidden phone fields are omitted. Content/context limits count Unicode code points, matching JSON Schema rather than Swift grapheme clusters. Boundary tests preserve that non-obvious contract lesson.

Result provenance comes from the response. `mock` always displays DEMO; live-requested mock additionally explains that NVIDIA was not used. `nvidia` alone selects “Analyzed with NVIDIA.” Human review flags say “Additional verification recommended.” Scores are heuristic, never proof or calibrated probabilities. There are no report writes or circle/Photon integration claims.

## Verification evidence — November 8, 2026

- Initial new lifecycle tests failed to compile before implementation because the draft/view-model types did not yet exist; then passed after implementation.
- `xcodebuild -list -project ios/Kavach.xcodeproj`: passed, Kavach scheme discovered.
- Release unsigned iPhone build: **BUILD SUCCEEDED**. Command uses `-configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/kavach-module1-release CODE_SIGNING_ALLOWED=NO`. Log: `/tmp/kavach-module1-build.log`.
- Existing `bash scripts/module0-integration.sh`: passed backend 86 tests, typecheck/build, health, valid/invalid POSTs, 32 Swift tests including ten actual HTTP tests, privacy checks and SpacetimeDB typecheck/build. Optional SpacetimeDB publish/reducer/query and its simulator step were not requested; simulator was run separately. Log: `/tmp/kavach-module1-integration.log`.
- Final host suite after adding settings/edit/retry coverage: **34 tests, zero failures, no skipped live HTTP tests**, using `KAVACH_LIVE_API_URL=http://127.0.0.1:3101 swift test --package-path ios --scratch-path /tmp/kavach-module1-tests`. Log: `/tmp/kavach-module1-core-final.log`.
- Final simulator run: **20 unit tests + 3 UI tests passed, zero failures or skips**, including manual offline submission, dark accessibility-XXXL missing-address guidance and live HTTP mock disclosure. Destination iPhone 16 Pro, iOS 18, `C22BC42D-7EEA-4254-8E8E-BAA254C90909`; command is in setup guide. Log: `/tmp/kavach-module1-xcode-final.log`.
- Generated app plist inspection: Debug contains local-network permission plus exact loopback HTTP exception; Release has **no `NSAppTransportSecurity` exceptions**.
- `git diff --check`: passed. No raw submitted content, provider credentials or new secrets were added to logs/code.

Actual HTTP evidence came from the unchanged mock backend bound to `127.0.0.1:3101`: health 200, analysis 200 with `source=mock`, invalid kind 400 `VALIDATION_ERROR`, malformed JSON 400 `INVALID_JSON`. Tests use synthetic content. This proves local mock contract integration, not Mac 2 connectivity or NVIDIA inference.

## Reproduce and continue

See [iOS setup](ios-setup.md) for simulator/phone Run steps, offline demonstration, endpoint selection and exact build/test commands. For the optional live-mock UI test, start the existing built backend on port 3101 with `HOST=127.0.0.1 PORT=3101 ANALYSIS_PROVIDER=mock node backend/dist/server.js` before running Xcode tests. The test skips when this local server is unavailable.

Person 2's handoff is now available at `docs/backend-module1-handoff.md`. Start Mac 2 with `HOST=0.0.0.0`, `PORT=3001`, `ANALYSIS_PROVIDER=nvidia`, its local `NVIDIA_API_KEY`, model `nvidia/nemotron-3.5-lightning-30b-a3b`, and `NVIDIA_THINKING=off`; run `cd backend && npm run dev`. In the app use `http://Chidatmas-MacBook-Pro.local:3001`, or re-check Mac 2's current IP with `ipconfig getifaddr en0`. Verify health, submit fictional content, and require `source=nvidia` before accepting the NVIDIA label. Never add provider credentials to the app.

Person 2 verified real NVIDIA execution and LAN health locally on Mac 2. Person 1 has not verified cross-Mac reachability, a physical-iPhone `source=nvidia` result, signing/installation/run, or interactive previews. Dark accessibility-size and source-disclosure UI tests cover specific screens, not a full VoiceOver/accessibility audit. Module 2 must implement actual report persistence before changing the session-only wording; circle/Photon work remains separate.
