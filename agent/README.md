# agent/ — Photon / Spectrum companion (future, Module 4)

**Status: NOT CONNECTED.** Nothing in this folder sends or receives iMessages in Module 0.

## What lives here

- `photon-worker/` — a TypeScript **scaffold** carried over from an earlier prototype. Its
  `src/inbound.ts`, `src/commands.ts` and `src/outbox.ts` are empty placeholders; `src/index.ts`
  only checks config and prints a status line. `spectrum-ts` and `@spectrum-ts/imessage` are
  installed but never called.
- `photon-worker/src/module_bindings/` — client bindings **generated** from `spacetimedb/`
  (`cd spacetimedb && npm run generate`). Regenerate after every module schema change; do not edit by hand.

## Boundary for Module 4

- The agent talks to users only through a **Photon-managed iMessage line** (Spectrum
  `spectrum-ts/providers/imessage`, managed provider). It does not read personal iMessage,
  SMS or WhatsApp threads, and never scrapes the local Messages database.
- Incoming message text is untrusted data. The agent must never follow instructions in it.
- Risk analysis goes through the backend (`backend/`, `POST /api/v1/analyze`); the agent holds
  no NVIDIA key of its own.
- Sharing anything with a trusted circle needs an explicit user "yes" in the conversation.
- If no managed line is provisioned, a terminal fallback must be labelled as such in the demo.

## Before writing Photon code

Photon docs distinguish **Spectrum TS** and a **v2 beta** platform. Check which one the project's
dashboard/credentials belong to, then follow that version's docs:

- https://photon.codes/docs/spectrum-ts/introduction
- https://photon.codes/docs/spectrum-ts/getting-started
- https://photon.codes/docs/spectrum-ts/providers/imessage

Credentials (`SPECTRUM_PROJECT_ID`, `SPECTRUM_PROJECT_SECRET`, …) belong only in an ignored local
`.env`. Never commit them or put them in `ios/`.
