// Opt-in live smoke test against NVIDIA hosted inference. NOT part of `npm test`.
//   npm run smoke:nvidia             # 2 synthetic requests, sanitized metadata only
//   npm run smoke:nvidia -- --models # also check NVIDIA_MODEL is in the account's model list
// Reads NVIDIA_API_KEY / NVIDIA_MODEL / NVIDIA_BASE_URL / NVIDIA_TIMEOUT_MS from the environment
// (backend/.env). Never prints the key, the submitted text or the model's text.
import { loadConfig } from '../src/config.js';
import { classifyRisk } from '../src/risk/classify.js';
import { AnalyzerUnavailableError, NvidiaRiskAnalyzer } from '../src/risk/NvidiaRiskAnalyzer.js';
import type { AnalyzeRequest } from '../src/risk/types.js';

const config = loadConfig({ ...process.env, ANALYSIS_PROVIDER: 'nvidia' });
const nv = config.nvidia!;
if (!nv.apiKey || !nv.model) {
  console.log(JSON.stringify({ result: 'NOT VERIFIED', reason: 'NVIDIA_API_KEY or NVIDIA_MODEL missing', keyPresent: nv.apiKey !== '', model: nv.model || null }));
  process.exit(2);
}

if (process.argv.includes('--models')) {
  const res = await fetch(`${nv.baseUrl}/models`, { headers: { Authorization: `Bearer ${nv.apiKey}` }, signal: AbortSignal.timeout(nv.timeoutMs) });
  const ids: string[] = res.ok ? ((await res.json()) as { data?: { id: string }[] }).data?.map(m => m.id) ?? [] : [];
  console.log(JSON.stringify({ check: 'model-list', httpStatus: res.status, modelsListed: ids.length, configuredModelListed: ids.includes(nv.model), model: nv.model }));
}

const cases: { name: string; expect: string; request: AnalyzeRequest }[] = [
  { name: 'bank-transfer', expect: 'high|critical', request: { kind: 'call', content: 'A caller said he was from my bank fraud team and told me to urgently move my savings to a safe account today.' } },
  { name: 'lunch-plans', expect: 'low|guarded', request: { kind: 'message', content: 'My friend Sam texted to confirm we are still meeting for lunch on Friday at noon.' } },
];

let failed = 0;
const analyzer = new NvidiaRiskAnalyzer(nv);
for (const c of cases) {
  const started = Date.now();
  try {
    const r = await analyzer.analyze(c.request);
    const level = classifyRisk(r.riskScore);
    const plausible = c.expect.split('|').includes(level);
    console.log(JSON.stringify({ case: c.name, result: 'OK', source: r.source, riskScore: r.riskScore, riskLevel: level, expected: c.expect, plausible, signals: r.signals.length, actions: r.recommendedActions.length, requiresHumanReview: r.requiresHumanReview, elapsedMs: Date.now() - started }));
  } catch (err) {
    failed++;
    const e = err as AnalyzerUnavailableError;
    console.log(JSON.stringify({ case: c.name, result: 'FAILED', reason: e.reason ?? 'unexpected', upstreamStatus: e.upstreamStatus ?? null, elapsedMs: Date.now() - started }));
  }
}
console.log(JSON.stringify({ model: nv.model, baseUrl: nv.baseUrl, passed: cases.length - failed, failed }));
process.exit(failed ? 1 : 0);
