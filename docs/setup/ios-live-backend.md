# Final live backend setup

Existing Module 1 LAN instructions remain in `../ios-setup.md`. The documented `Chidatmas-MacBook-Pro.local:3001` health check currently fails DNS resolution from Mac 1. No public HTTPS endpoint is supplied. Reconfirm Mac 2's current reachable address and shared network; a historical IP is not evidence of current reachability.

Use HTTPS for user authentication and private data. Never add blanket ATS exceptions. Debug local analysis permits `.local` networking and exact loopback HTTP support; Release retains ATS defaults. Use only fictional analysis text for development HTTP checks.

Person 2 must publish `docs/contracts/ios-api-v1.md`, versioned schemas and fixtures for auth, profiles, reports, circles, events, devices and agent linking with an immutable commit SHA. Include nonce encoding, refresh rotation/replay rules, idempotency behavior, pagination and SSE cursor semantics. Merge compatibility must then be tested with actual authenticated accounts and database persistence; Git merge success alone is insufficient.
