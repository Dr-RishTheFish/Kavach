# kavach iOS setup

Module 0 provides an offline SwiftUI app with Home, Analyze, Circle and Settings. It does not connect to NVIDIA, Photon, SpacetimeDB, contacts, calls or personal messages.

## Toolchain and project

Observed on November 8, 2026: Xcode 27.2 (27B52), Apple Swift 6.4.2, iPhone/iOS Simulator SDK 27.2. The app targets iOS 17.0 and uses Swift 5 language mode. Ruby `xcodeproj` 1.24.0 generated the committed project; no generator or external dependency is required to open or build it.

Open `ios/Kavach.xcodeproj` in Xcode. The discovered scheme is **Kavach**, with app, unit-test and UI-test targets. SwiftUI previews are declared for the root and Analyze screen; interactive previews have not been verified.

```sh
open ios/Kavach.xcodeproj
xcodebuild -list -project ios/Kavach.xcodeproj
xcodebuild -showdestinations -project ios/Kavach.xcodeproj -scheme Kavach
```

## Bundle identifier and physical iPhone

After the user delegated identifier selection, the development identifier was set to `com.rishthefish.kavach` in `ios/Configuration/App.xcconfig`. Availability for distribution has not been checked; it can be changed before release.

1. Confirm the development identifier or replace it with one appropriate for your account. Set `KAVACH_BUNDLE_IDENTIFIER` in `ios/Configuration/App.xcconfig`, or set it in ignored `ios/Configuration/Local.xcconfig` for a local override.
2. In Xcode, select the Kavach app target → Signing & Capabilities → your Apple Development team. Use automatic signing. No team or signing identity is embedded in the project.
3. Connect your iPhone, unlock it and trust the Mac. Enable Developer Mode under Settings → Privacy & Security when requested. Pair it in Xcode’s Devices and Simulators window; wireless use requires pairing first.
4. Select the connected iPhone running iOS 17 or newer, and Run. Xcode may need matching platform support for the phone’s OS.

A physical iPhone has **not been verified**. No device identifier, development team or provisioning profile was guessed. Simulator installation does not need your Apple team.

## Build and tests

Unsigned simulator compilation, including both test targets:

```sh
xcodebuild build-for-testing -project ios/Kavach.xcodeproj -scheme Kavach \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/kavach-derived CODE_SIGNING_ALLOWED=NO
```

Unsigned iPhone SDK compilation:

```sh
xcodebuild build -project ios/Kavach.xcodeproj -scheme Kavach \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/kavach-device-derived CODE_SIGNING_ALLOWED=NO
```

The same Foundation model/service sources can be tested on this Mac without an iOS runtime or bundle identifier:

```sh
swift test --package-path ios --scratch-path /tmp/kavach-swift-tests
```

This runs 12 XCTest tests for score boundaries, invalid assessments, canonical JSON decoding and date round trips, request fields, mock fixtures, HTTP method/path/headers/body, API errors, malformed responses, timeout propagation, cancellation before submission and URL configuration. Every HTTP test uses an ephemeral URLSession with URLProtocol stubs; no live server is called. Run serially: the stub handler is shared within the test process.

Run iOS tests against a destination returned by discovery. This Mac has an iPhone 16 Pro / iOS 18.0 simulator:

```sh
xcodebuild test -project ios/Kavach.xcodeproj -scheme Kavach \
  -destination 'platform=iOS Simulator,id=C22BC42D-7EEA-4254-8E8E-BAA254C90909' \
  -derivedDataPath /tmp/kavach-derived CODE_SIGNING_ALLOWED=NO
```

The final simulator run passed all **12 unit tests and 1 UI smoke test** (exit 0). The UI test visits all four tabs and checks demo disclosures. Its [actual Home screenshot](../ios/Verification/home-simulator.png) was exported and visually inspected in light appearance. Dark appearance, accessibility-size Dynamic Type and interactive previews remain **NOT VERIFIED**. An earlier attempt failed installation with a missing bundle identifier; that was resolved by the user-authorized identifier selection.

## What the tabs do

| Tab | Module 0 behavior |
| --- | --- |
| Home | Offline overview, sample risk result, practical guidance and a working Analyze shortcut |
| Analyze | Call, Text/SMS, Message and URL fixtures; five scenarios spanning all four risk levels; explanatory signals and next steps |
| Circle | Explicit preview members and an empty alerts state; no accounts, invitations or sharing |
| Settings | Demo status, locally saved development address, privacy explanation and future-feature status |

The reusable UI uses native system surfaces, semantic risk colors plus text labels, scalable typography, scrolling layouts and horizontal-to-vertical score-card fallback. All mock score cards show “DEMO · Simulated assessment.” Low risk is never represented as a guarantee of safety.

## Service selection and API configuration

`AnalyzeView` explicitly injects `MockAnalysisService` through the `AnalysisService` protocol. It matches exact synthetic fixture content; unmatched text receives a cautious guarded mock result requiring further review. The mock never visits URLs or uses AI. Home displays a fixed sample.

`HTTPAnalysisService` is implemented for future integration and exercised only by stub tests. It accepts a base URL and optional URLSession/timeout, posts JSON to `api/v1/analyze`, preserves API error details, validates score/level consistency and response kind, and propagates network errors and cancellation. It never silently falls back to a mock.

Settings stores `developmentAPIBaseURL` in UserDefaults. **Saving it does not switch services or make any network call.** Module 1 can explicitly construct `HTTPAnalysisService` from that configured URL when live submission is authorized. There is no user submission form in Module 0.

On a physical iPhone, `localhost` means the phone. Later LAN testing requires the backend Mac’s reachable LAN hostname/address and an explicitly enabled LAN bind. Use test data only. The project contains no broad App Transport Security exception and no local-network permission prompt. Prefer HTTPS; any development HTTP exception and local-network usage description must be narrowly configured and tested when LAN integration is introduced. Do not put API secrets in the app or send production credentials over plaintext HTTP.

## Contract integration

The supplied `API_CONTRACT_V0.md` is authoritative. `ios/KavachTests/Fixtures/assessment.json` copies its canonical response without adapting fields. Models use `analysisId`, never a persisted `reportId`. Timestamps support fractional and whole-second ISO 8601 forms.

The starter-kit docs currently live in the supplied Downloads folder, not this repository. Person 2’s `shared/contracts/` fixtures are not yet present. After the common docs and contract PR merge, review the canonical generated fixture and run the same decoder tests against it before integrating live HTTP. Do not silently rename or adapt fields to make tests pass.

Implementation uses Apple’s documented [TabView](https://developer.apple.com/documentation/swiftui/tabview), [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack), and [URLSession async request API](https://developer.apple.com/documentation/foundation/urlsession/data(for:delegate:)).
