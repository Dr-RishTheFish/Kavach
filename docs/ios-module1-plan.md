---
title: iOS Module 1 - Plan
type: feat
date: 2026-11-08
artifact_contract: ce-unified-plan/v1
product_contract_source: module-1-person-1-brief
execution: code
---
# iOS Module 1 - Plan

## Goal Capsule

**Objective:** A person can manually investigate suspicious content on iPhone and understand whether the displayed assessment is simulated or supplied by NVIDIA.

**Means:** Extend the existing SwiftUI app and AnalysisService boundary (KTD1–KTD4).

**Authority:** The user's current approval governs execution and deferrals; the supplied `MODULE_1_PERSON_1_CODEX.md` governs features; actual `shared/contracts/` governs wire compatibility. Preserve the supplied brief unchanged.

**Execution:** One local change on `feature/ios-module-1`, based on `feature/module-0-integration` at `f8860760c396437600061c90e7c12ae616d25b14`. Implementation, verification, and handoff are authorized; publishing and merging require later approval. Stop for incompatible required contract changes or unsafe edits to another owner's work.

---

## Product Contract

### Summary

Replace the fixture-only Analyze flow with a validated manual form, cancellable analysis, honest results, and persisted nonsecret service configuration.

### Problem Frame

Module 0 demonstrates sample assessments but does not let a person submit their own suspicious content to the integrated HTTP service.

### Requirements

**Manual submission**

- R1. Implement the four distinct kinds and fields specified in brief §4A, preserving schema validation and omitting blank optional values.
- R2. Only an explicit Analyze or Retry action sends content; show consent for Live backend and disable invalid or duplicate submissions.
- R3. Expose idle, validating, loading, success, and failure with cancellation and protection against stale results after edits, mode changes, endpoint changes, or navigation.

**Assessment and configuration**

- R4. Render score, accessible severity, interpretation, summary, signals, actions, timestamp, and actual response source according to brief §4C. Mock returned through HTTP remains visibly simulated; additional verification never implies human review occurred.
- R5. Default to offline mock; allow Live backend selection and a configurable base URL. Missing configuration produces guidance without fallback.
- R6. Persist only nonsecret configuration. Keep content and assessments session-only, never log submitted text or credentials, and restrict local HTTP support to development configuration.
- R7. Map known and unknown backend errors, transport failures, and malformed results to actionable messages without inventing an assessment.

**Verification and ownership**

- R8. Preserve Module 0 tabs and exact contracts. Change only `ios/` and iOS documentation; preserve `.claude/settings.json` and partner-owned directories.
- R9. Verify against the existing mock backend now. Real NVIDIA, Mac 2 LAN, and physical-phone checks remain explicitly pending under the user's latest instruction.
- R10. Deliver updated setup instructions and `docs/ios-module1-handoff.md` with actual test outcomes, branch/base identity, source provenance, and remaining Person 2 handshake steps.

### Scope Boundaries

Brief §9 exclusions remain binding: no report persistence, circle delivery, Photon, extensions, message interception, push notifications, or deployment. A health probe is considered but omitted because it does not establish provider availability and is unnecessary for this submission flow. Reconsider if connection diagnostics prove insufficient.

---

## Planning Contract

### As-found inventory

- The integrated base contains accepted iOS and backend Module 0 ancestry. The initial tracked tree was clean; one unrelated untracked `.claude/settings.json` is preserved.
- `ios/Kavach/KavachApp.swift` supplies Home, Analyze, Circle, and Settings navigation stacks. Analyze currently selects local demo scenarios and automatically requests the mock on selection.
- `ios/Kavach/Core/Models.swift` already centralizes kinds, DTOs, sources, risk boundaries, score/level consistency, API error envelopes, and date decoding.
- `ios/Kavach/Core/AnalysisService.swift` already provides injected URLSession HTTP and offline mock services, request cancellation checks, status handling, and response-kind validation. Preserve this boundary.
- `ios/Kavach/Core/DesignSystem.swift` supplies reusable cards, badges, and accessible text. Extend presentation without replacing the existing design system.
- Settings currently stores `developmentAPIBaseURL` and remains mock-only. There is no live service selection or shared app settings object.
- `ios/Package.swift` runs host tests over Core; Xcode has app, unit-test, and UI-test targets. Source registration is explicit in `ios/Kavach.xcodeproj/project.pbxproj` and `ios/scripts/generate-project.rb`.
- Actual contract version is v0.1.0 at the base above. Backend uses a mock provider; compatible extra errors include unsupported-media-type and not-found. No required wire mismatch was found in parent reconnaissance.
- Required charter/Module 0 briefs are supplied from the starter-kit download because `docs/hackathon/` is absent in this checkout. Do not recreate or mutate shared contract documents.

### Key Technical Decisions

- KTD1. **Preserve the service and DTO boundary.** Add a request-draft validator rather than a parallel network stack; this keeps Module 0 compatibility and existing URLProtocol tests useful (R1, R8).
- KTD2. **Count Unicode scalars.** JSON Schema length semantics match code points, not Swift grapheme-cluster counts; trim before validation and validate optional phone/context consistently (R1).
- KTD3. **Own requests in a main-actor view model.** Use explicit state, cancellation, and a generation token; resolve a dependency factory only at submission. Invalidation prevents cancellation-ignoring completions from replacing current state (R2, R3).
- KTD4. **Share settings at the app root.** Persist mode/base URL only; observe configuration changes to invalidate outstanding analysis. Response source, never configuration, chooses result labeling (R4–R6).
- KTD5. **Keep development transport narrow.** Use debug-only local-network configuration and explicit approved host/IP exceptions where required, with HTTPS for deployed use. Do not enable arbitrary loads. Apple references: [local networking](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking), [ATS domains](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSAppTransportSecurity/NSExceptionDomains), and [local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy) (R6).

### High-Level Technical Design

Directional dependency flow: manual form → request draft → main-actor view model → selected AnalysisService → validated assessment → source-aware result view. App settings supplies selection/configuration to the factory and invalidates current work when changed.

Directional lifecycle: idle → validating → loading → success or failure. Cancel or input/configuration invalidation advances the generation and returns to idle; obsolete completion is ignored. Retry traverses validation again and never silently switches provider.

Mode matrix: offline selects MockAnalysisService without network; Live with invalid configuration yields guidance without creating HTTP work; Live with valid configuration selects HTTPAnalysisService. Both services render the source carried by their result.

---

## Implementation Units

### U1. Contract-compatible draft and request lifecycle

**Goal:** Make manual submission deterministic and safe before wiring views. **Requirements:** R1–R3, R5–R8. **Dependencies:** existing Core models/services.

**Files:** New Core draft/settings/view-model files under `ios/Kavach/Core/`; tests under `ios/KavachTests/` for draft validation, settings, view-model lifecycle, and HTTP behavior; project and generator source registration as needed.

**Approach:** Apply KTD1–KTD4 using existing models and injected services. Keep helpers host-testable. Map errors centrally to safe display messages.

**Execution note:** Implement domain and lifecycle behavior test-first.

**Test scenarios:**

- Empty/whitespace, 5000/5001 scalar content, combining marks, emoji, optional context limits, and invalid E.164-like numbers produce the expected request or local error.
- All four kinds preserve machine values; blank optionals are omitted and hidden phone input does not leak to message/URL requests.
- Valid submission calls the selected service once; duplicate Analyze and view refresh do not call it again.
- Cancel, input edits, mode changes, and endpoint edits ignore late completion from a cancellation-ignoring service.
- Failure permits retry; timeout, offline, unknown code, malformed payload, and known errors remain actionable.
- Persistent settings contain configuration only and default to offline.

**Verification:** Host tests prove validation and lifecycle without relying on SwiftUI scheduling; they do not prove rendered accessibility or device networking.

### U2. Manual form, honest results, and configuration UI

**Goal:** Expose the validated flow in the existing tabs. **Requirements:** R1–R8. **Dependencies:** U1.

**Files:** `ios/Kavach/KavachApp.swift`, Analyze/Settings/Home views under `ios/Kavach/Features/`, `ios/Kavach/Core/DesignSystem.swift`, configuration files under `ios/Configuration/`, Xcode project/generator, `ios/KavachUITests/`, and relevant presentation tests in `ios/KavachTests/`.

**Approach:** Bind the form to U1, show mode-specific consent and setup guidance, add source-aware result presentation, and apply KTD5. Preserve native controls, light/dark colors, and Dynamic Type. Provide previews covering all bands and states.

**Test scenarios:**

- Fresh launch makes no request; submitting valid text shows loading then result, and cancellation restores editing.
- Each kind has its own accessible label and contextual placeholder; optional phone appears only for call/SMS.
- Offline and HTTP mock results show prominent simulation labels; synthetic NVIDIA results show NVIDIA only from response data.
- Empty signals render an appropriate empty state; human-review flag uses the approved wording.
- Live without URL guides setup; saving configuration or switching tabs does not submit content.
- Verify error/retry, risk boundaries, light/dark appearance, and large text without clipping essential controls.

**Verification:** Simulator UI tests prove actual interaction and visible labels; previews and visual inspection cover presentation. Neither proves physical LAN or real NVIDIA execution.

### U3. Integrated mock verification and handoff

**Goal:** Leave a reproducible iOS deliverable for Person 2's later live handshake. **Requirements:** R8–R10. **Dependencies:** U1, U2.

**Files:** Existing live-backend tests under `ios/KavachTests/`, `docs/ios-setup.md`, `docs/ios-module1-handoff.md`.

**Approach:** Exercise the unchanged local mock HTTP backend with synthetic input, inspect final diff for ownership and secrets, and record exact evidence. Document localhost-on-phone behavior, synthetic-only HTTP testing, configuration, and required Person 2 metadata without credentials.

**Test scenarios:**

- Local HTTP analysis for all kinds preserves contract, source, risk mapping, and safe failures.
- Existing Module 0 host and simulator suites still pass with new tests registered in the correct targets.
- Debug configuration permits only intended development behavior; Release retains normal transport protections.

**Verification:** Separate automated host/simulator results from unperformed device, Mac 2 LAN, NVIDIA, and signing checks.

---

## Verification Contract

Use the existing Swift package test harness and `scripts/module0-integration.sh` for contract and mock HTTP proof. Run `xcodebuild -list`, a scheme-appropriate build, and tests on an available simulator. Record actual commands and outcomes in the handoff, including environment/toolchain limitations. The existing iPhone 16 Pro simulator is a candidate, not proof of availability at execution time.

Review the final owned-path diff using Compound Engineering code review and address substantive findings. Preserve raw request content and credentials from logs. No test success may be reported without observed output.

---

## Definition of Done

U1–U3 satisfy their verification outcomes, required Module 0 regressions pass, and the handoff clearly identifies every deferred live/device check. Remove abandoned experimental code. No partner-owned file, shared schema, uncommitted partner work, or branch is modified. Work remains local for user review.
