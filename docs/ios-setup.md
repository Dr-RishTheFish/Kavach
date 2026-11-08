# kavach iOS setup

Module 1 adds manual analysis of calls, SMS, other messages and links. Offline mock is the default. Live mode sends user-entered text to the configured backend only after Analyze is tapped. The app does not read calls/messages, open submitted links, save reports or share with circles.

## Open and run

Open `ios/Kavach.xcodeproj`, choose **Kavach**, select a simulator or connected iPhone, and press **Run (⌘R)**. Build alone does not launch the app.

Observed toolchain: Xcode 27.2 (27B52), Swift 6.4.2, Swift 5 language mode, iOS 17 minimum. No project generator or external iOS package is needed. `ios/scripts/generate-project.rb` can regenerate the project with Ruby xcodeproj 1.24.

For a phone, select your development team under Signing & Capabilities, unlock/trust the phone, and enable Developer Mode. If installation succeeds but launch reports an untrusted developer, trust your development certificate in Settings → General → VPN & Device Management. The default bundle identifier is `com.rishthefish.kavach`; override `KAVACH_BUNDLE_IDENTIFIER` in ignored `ios/Configuration/Local.xcconfig` if needed. Module 1 physical-phone signing and execution remain unverified.

## Offline demonstration

1. Settings → Service → **Mock (offline)**.
2. Analyze → choose the contact kind and enter synthetic text, or select a fictional example.
3. Tap **Analyze demo**. Selecting a sample alone never submits.
4. Results display **DEMO · Simulated assessment**, score, severity, explanation, signals, actions and timestamp. Mock handles all four kinds without networking.

Content is trimmed and must contain 1–5000 Unicode code points. Context is optional, up to 1000 code points. Call/SMS optionally accepts an international number beginning with `+` and 1–15 ASCII digits, without a leading zero. Blank optional fields are omitted; phone input is omitted for message/link. Invalid fields disable Analyze.

Editing input, switching service/endpoint, leaving Analyze, or cancelling invalidates pending work. Duplicate submission is blocked. Errors retain input for retry. Content and results are session-only; only service mode and address persist.

## Existing mock backend

From the repository root, using the installed Node 26 toolchain:

```sh
export PATH=/opt/homebrew/opt/node@26/bin:$PATH
npm --prefix backend run dev
```

The existing backend uses loopback port 3001 by default. In a simulator, save `http://127.0.0.1:3001` in Settings and select **Live backend**. Submit synthetic text. A successful HTTP response from this backend still carries `source=mock`, so the app displays the simulated label and explains that NVIDIA was not used. There is no silent fallback when an address is missing or a server fails.

`GET /health` shows server availability only, not inference-provider readiness. Automated local integration starts an isolated mock backend on port 3101:

```sh
export PATH=/opt/homebrew/opt/node@26/bin:/Users/rishthefish/.local/bin:$PATH
bash scripts/module0-integration.sh
```

## Mac 2 LAN and NVIDIA integration

Person 2's backend is committed at `76579f8` and keeps contract v0.1.0. On Mac 2, create the gitignored `backend/.env` with these settings, supplying the key locally rather than sharing or committing it:

```dotenv
HOST=0.0.0.0
PORT=3001
ANALYSIS_PROVIDER=nvidia
NVIDIA_API_KEY=<local secret>
NVIDIA_MODEL=nvidia/nemotron-3.5-lightning-30b-a3b
NVIDIA_THINKING=off
```

Start it with `cd backend && npm run dev`. Confirm `http://localhost:3001/health` on Mac 2 before testing from another device. Mac 2's preferred address recorded in the backend handoff is `http://Chidatmas-MacBook-Pro.local:3001`; if name resolution fails, re-check its current IP with `ipconfig getifaddr en0` and use `http://<current-ip>:3001`. The previously observed `10.176.197.173` may change. Allow Node through the macOS firewall, keep both devices on the same trusted Wi-Fi, and select **Live backend** in the app. Submit fictional text explicitly and confirm that the result says **Analyzed with NVIDIA**. A `mock` response must retain the DEMO label, and a 503 must remain an error with retry available.

On a physical iPhone, localhost means the phone. Never copy `NVIDIA_API_KEY` into Xcode, the app, UserDefaults, an Info.plist, or messages between Macs. The iPhone sends only the analysis request to Mac 2; Mac 2 owns the NVIDIA credential.

Prefer HTTPS. Plain HTTP can expose submitted content: use fictional text only. `Info-Debug.plist` permits local networking and an exact `127.0.0.1` HTTP exception for simulator development. For a numeric LAN address, add only the actual backend IP under Debug `NSExceptionDomains` with `NSExceptionAllowsInsecureHTTPLoads=true`; do not add broad arbitrary-load exceptions or placeholder IPs. Remove obsolete host exceptions when the endpoint changes. `Info-Release.plist` contains no ATS exception. Both configurations provide a local-network permission explanation. See Apple's [local networking setting](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking).

Person 2 verified live NVIDIA inference and LAN health locally on Mac 2. Cross-Mac and physical-iPhone reachability, iOS rendering of an actual `source=nvidia` response, physical-phone signing, and installation remain unverified by Person 1.

## Build and tests

```sh
xcodebuild -list -project ios/Kavach.xcodeproj
xcodebuild build -project ios/Kavach.xcodeproj -scheme Kavach \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/kavach-module1-release CODE_SIGNING_ALLOWED=NO
swift test --package-path ios --scratch-path /tmp/kavach-module1-tests
xcodebuild test -project ios/Kavach.xcodeproj -scheme Kavach \
  -destination 'platform=iOS Simulator,id=C22BC42D-7EEA-4254-8E8E-BAA254C90909' \
  -derivedDataPath /tmp/kavach-module1-derived CODE_SIGNING_ALLOWED=NO
```

Choose an available simulator with `xcodebuild -showdestinations` if that identifier differs on another Mac. Host tests without `KAVACH_LIVE_API_URL` skip the ten live HTTP tests; the integration script supplies the URL and runs them. URLProtocol tests should run serially because the stub handler is shared.

Tests cover risk boundaries, dates, exact request/response contract, malformed data, service errors, cancellation, draft limits, stale results, retry and nonsecret settings. Simulator tests exercise manual submission, four tabs, demo disclosure and dark accessibility-size setup errors. Consult [the Module 1 handoff](ios-module1-handoff.md) for observed results and remaining verification limits.

## Contract and ownership

Swift preserves `shared/contracts/` v0.1.0 through backend commit `76579f8`; that commit changes only the error schema description, with no key, type, or semantic wire change. `analysisId` is transient, not a report ID. Scores must agree with severity bands. Labels follow the response's `source`: NVIDIA appears only for `nvidia`; mock remains simulated even over HTTP. Additional verification does not imply a human reviewed the result.

Home retains sample guidance; Circle remains an explicit preview. Reports, Photon, SpacetimeDB subscriptions, alerts and device-message access are outside Module 1.
