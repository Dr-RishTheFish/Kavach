// photon-worker entry point (spec section 9). Scaffold only.
// Responsibilities: receive messages from Photon Spectrum (inbound.ts), parse text commands
// (commands.ts), and deliver queued outbox rows (outbox.ts).
const required = ['SPACETIME_URI', 'SPACETIME_DB_NAME', 'AGENT_SERVICE_URL'] as const;
const missing = required.filter(k => !process.env[k]);
if (missing.length) console.warn(`[photon-worker] missing config: ${missing.join(', ')}`);

console.log(JSON.stringify({ service: 'photon-worker', status: 'scaffold', demoMode: process.env.DEMO_MODE === 'true' }));
