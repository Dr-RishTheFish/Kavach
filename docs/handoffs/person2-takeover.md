# Claude / Person 2 takeover — 2026-11-08

The user now assigns the remaining project to Claude / Person 2, including finishing the iOS integration. The immediate goal is reachable NVIDIA analysis, followed by the complete real product. Preserve all existing work and confirm the current user's authority before any destructive or external account action.

## Exact current state

Mac 1 workspace `/Users/rishthefish/Projects/Kavach`, branch `feature/final-ios`, HEAD `85ee3e2`. Published Module 1 is `e9dfbea` on `feature/ios-module-1`; it includes NVIDIA backend commit `76579f8`. The final-backend commit `85ee3e2` adds plans/handoff, not implemented final APIs.

At handoff capture, final iOS changes were uncommitted. The user subsequently authorized publishing `feature/final-ios`; use that branch's latest commit for the delivered code and verify its remote SHA. Earlier handoffs record historical pre-publication status. Do not rebuild these changes blindly. Preserve the entire working tree; `.claude/settings.json` is unrelated local configuration and must not be published.

Changed tracked files: `ios/Kavach.xcodeproj/project.pbxproj`, `ios/Kavach/KavachApp.swift`, `ios/Kavach/Features/{AnalyzeView,CircleView,SettingsView}.swift`, `ios/KavachUITests/NavigationTests.swift`.

New code: `ios/Kavach/Core/{FinalFoundation,FinalDemo}.swift`, `ios/Kavach/Features/FinalWorkspaceView.swift`, `ios/KavachTests/{FinalFoundationTests,FinalDemoTests}.swift`.

New documentation: `docs/handoffs/{final-ios-baseline,person1-final,person2-takeover}.md`, `docs/ios-final-{architecture,plan}.md`, `docs/setup/ios-{signing-and-apns,live-backend,photon-messages}.md`, `docs/testing/ios-final-acceptance.md`.

Read `docs/handoffs/person1-final.md` for Person 2 section 9 decisions, `docs/handoffs/person2-to-person1-final-ui.md` for the explicitly draft UI-first agreement, and both full final-build briefs supplied by the user. The current UI demo implements memory-only fictional accounts, private reports, circles/invites, consented sharing and alert feed. It is clearly labeled DEMO and never sends those flows to the backend. Existing manual analysis has real HTTP/NVIDIA support. Keychain/nonce/SSE framing primitives exist but are not integrated into real authentication or events.

## Make analysis reachable first

Same-Wi-Fi diagnosis on Mac 2:

1. Keep NVIDIA key only in gitignored `backend/.env`. Set `HOST=0.0.0.0`, `PORT=3001`, `ANALYSIS_PROVIDER=nvidia`, the account's valid `NVIDIA_MODEL` and local key. Prior verified model: `nvidia/nemotron-3.5-lightning-30b-a3b`, `NVIDIA_THINKING=off`.
2. With Node >=22, run `cd backend && npm run dev`.
3. Verify `curl -fsS http://127.0.0.1:3001/health` on Mac 2. Determine current LAN IP with `ipconfig getifaddr en0` (check the actual active interface if empty).
4. Allow Node through macOS firewall. Put iPhone and Mac 2 on the same non-isolated network. Verify `http://<current-Mac2-IP>:3001/health` from another device before debugging the app. Guest/campus Wi-Fi may block peer traffic.
5. Use the actual reachable address in Kavach Settings and select Live backend. The historical `.local` hostname failed resolution from Mac 1. Numeric HTTP may need the exact IP in Debug ATS exceptions; never enable global arbitrary loads or put development HTTP into Release.
6. Submit fictional text explicitly. Only claim NVIDIA when the actual response has `source=nvidia` and the iPhone renders that label. A server health response alone does not prove provider inference.

For off-LAN/reliable demonstrations, deploy the API to an approved host with a stable public HTTPS URL. Build with `npm --prefix backend run build`, start the compiled server via its documented `start` script, configure the platform's port/bind settings and secret store, and verify health plus synthetic analysis externally. Inspect the current config before adapting platform settings. Do not expose the development server directly to the Internet. Workers/SSE require suitable long-running hosting; do not pick a host or incur spend without the owner's applicable approval. The user session APIs, database and workers must be implemented before authenticated feature testing.

## Remaining implementation

Publish canonical `shared/contracts/v1/` schemas and fixtures before replacing demos with HTTP. Implement verified auth/refresh/logout, private SpacetimeDB persistence, circle authorization/idempotent sharing, authenticated SSE catch-up, real device registry/APNs outbox, and Photon managed-line/linking. Replace UI adapters against those contracts without guessing. Never use demo identities as backend authorization.

Real Apple sign-in/push entitlements and provisioning, server-only APNs key, two independent accounts, public HTTPS and a real managed Photon line remain external gates. A signed baseline installed and launched on Mac 1's physical iPhone, but no real APNs or managed Messages interaction was demonstrated. Do not claim completion from compilation, merge success, simulator injection or mock UX.

## Existing verification

Final UI host suite: 43 discovered, 33 executed, 10 HTTP tests skipped, zero failures. Simulator: 29 unit + 4 UI tests passed. Prior integrated Module 1 run: backend177 + Swift34 including real loopback HTTP passed. Signed baseline build/install/launch passed. `git diff --check` passed; no provider keys found in iOS.

Run meaningful contract, authorization, privacy, concurrency and physical-provider tests after integration. Exact current logs and gate matrix are in `docs/testing/ios-final-acceptance.md`. Preserve source labels and separate Save/Share consent. Report what is committed/pushed and exact remaining blockers. Never auto-merge main, reset work, or force-push.
