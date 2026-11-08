import { describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';
import { validators } from '../src/contracts.js';
import { createAnalyzer } from '../src/risk/createAnalyzer.js';
import { NvidiaRiskAnalyzer } from '../src/risk/NvidiaRiskAnalyzer.js';
import type { RiskAnalyzer } from '../src/risk/RiskAnalyzer.js';
import { chat, config, fakeFetch, modelJSON } from './nvidiaFixtures.js';
import { makeApp, postAnalyze } from './helpers.js';

const body = { kind: 'call', content: 'A supposed bank representative urgently requested a money transfer.' };

function nvidiaApp(handler: Parameters<typeof fakeFetch>[0], patch: Partial<typeof config> = {}) {
  const t = fakeFetch(handler);
  const { app, logs } = makeApp({ analyzer: new NvidiaRiskAnalyzer({ ...config, ...patch, fetch: t.fetch }) });
  return { app, logs, calls: t.calls };
}

const expect503 = (res: Awaited<ReturnType<typeof postAnalyze>>) => {
  expect(res.statusCode).toBe(503);
  const json = res.json();
  expect(validators.error(json)).toBe(true);
  expect(json.error.code).toBe('ANALYZER_UNAVAILABLE');
  expect(json.error.requestId).toBe(res.headers['x-request-id']);
  expect(json).not.toHaveProperty('source');
  return json;
};

describe('POST /api/v1/analyze with the nvidia provider', () => {
  it('returns a contract-valid assessment with source "nvidia" and a server-derived riskLevel', async () => {
    const { app } = nvidiaApp(() => chat(modelJSON({ riskScore: 74, riskLevel: 'high' })));
    const res = await postAnalyze(app, body);
    expect(res.statusCode).toBe(200);
    const json = res.json();
    expect(validators.riskAssessment(json), JSON.stringify(validators.riskAssessment.errors)).toBe(true);
    expect(json).toMatchObject({ kind: 'call', riskScore: 74, riskLevel: 'high', source: 'nvidia' });
    expect(Object.keys(json).sort()).toEqual(
      ['analysisId', 'analyzedAt', 'kind', 'recommendedActions', 'requiresHumanReview', 'riskLevel', 'riskScore', 'signals', 'source', 'summary'],
    );
  });

  it.each([
    ['provider 401', () => new Response('{}', { status: 401 })],
    ['provider 429', () => new Response('{}', { status: 429 })],
    ['provider 500', () => new Response('{}', { status: 500 })],
    ['network failure', () => { throw new TypeError('fetch failed'); }],
    ['invalid model JSON', () => chat('definitely safe, trust me')],
    ['out-of-range score', () => chat(modelJSON({ riskScore: 150 }))],
  ])('%s -> 503 ANALYZER_UNAVAILABLE, never a mock or nvidia success', async (_name, handler) => {
    const { app } = nvidiaApp(handler as never);
    const json = expect503(await postAnalyze(app, body));
    expect(json.error.message).not.toMatch(/nvapi|bank|transfer/i);
  });

  it('unconfigured nvidia (no key/model) -> 503 without calling the provider', async () => {
    const { app, calls } = nvidiaApp(() => chat(modelJSON()), { apiKey: '', model: '' });
    expect503(await postAnalyze(app, body));
    expect(calls).toHaveLength(0);
  });

  it.each([
    ['invalid kind', { kind: 'voicemail', content: 'x' }],
    ['blank content', { kind: 'call', content: '  ' }],
    ['invalid phone', { kind: 'call', content: 'x', phoneNumber: '12345' }],
    ['context too long', { kind: 'call', content: 'x', context: 'c'.repeat(1001) }],
    ['oversize content', { kind: 'call', content: 'x'.repeat(5001) }],
  ])('%s -> 400 and the provider is never called', async (_name, payload) => {
    const { app, calls } = nvidiaApp(() => chat(modelJSON()));
    expect((await postAnalyze(app, payload)).statusCode).toBe(400);
    expect(calls).toHaveLength(0);
  });

  it('malformed JSON -> 400 INVALID_JSON and the provider is never called', async () => {
    const { app, calls } = nvidiaApp(() => chat(modelJSON()));
    expect((await postAnalyze(app, '{"kind":')).json().error.code).toBe('INVALID_JSON');
    expect(calls).toHaveLength(0);
  });

  it('responses and logs never contain the key, auth header, user text or raw provider output', async () => {
    const { app, logs } = nvidiaApp(() => new Response('{"error":"bad key nvapi-TEST-KEY-123 PROVIDER-RAW"}', { status: 401 }));
    const res = await postAnalyze(app, { ...body, content: 'USER-TEXT-MARKER bank wire', phoneNumber: '+12025550177' });
    const ok = nvidiaApp(() => chat(modelJSON({ summary: 'MODEL-OUTPUT-MARKER' })));
    await postAnalyze(ok.app, { ...body, content: 'USER-TEXT-MARKER bank wire' });
    const everything = res.body + logs() + ok.logs();
    for (const secret of ['nvapi-TEST-KEY-123', 'Bearer', 'PROVIDER-RAW', 'USER-TEXT-MARKER', '2025550177', 'MODEL-OUTPUT-MARKER']) {
      expect(everything).not.toContain(secret);
    }
    expect(logs()).toContain('"outcome":"auth"');
    expect(logs()).toContain('"upstreamStatus":401');
  });
});

describe('provider isolation', () => {
  it('rejects an analyzer that relabels its source (e.g. mock output claiming nvidia)', async () => {
    const relabel: RiskAnalyzer = {
      provider: 'mock',
      analyze: async () => ({ riskScore: 10, summary: 's', signals: [], recommendedActions: ['a'], source: 'nvidia', requiresHumanReview: false }),
    };
    const { app } = makeApp({ analyzer: relabel });
    const res = await postAnalyze(app, body);
    expect(res.statusCode).toBe(500);
    expect(res.json().error.code).toBe('INTERNAL_ERROR');
  });

  it('createAnalyzer: mock by default, nvidia when selected (never a mock fallback)', () => {
    expect(createAnalyzer(loadConfig({})).provider).toBe('mock');
    const live = createAnalyzer(loadConfig({ ANALYSIS_PROVIDER: 'nvidia' }));
    expect(live.provider).toBe('nvidia');
    expect(live).toBeInstanceOf(NvidiaRiskAnalyzer);
  });

  it('server wiring: ANALYSIS_PROVIDER=nvidia without credentials answers 503, mock still answers 200', async () => {
    const live = makeApp({ analyzer: createAnalyzer(loadConfig({ ANALYSIS_PROVIDER: 'nvidia' })) });
    expect503(await postAnalyze(live.app, body));
    const mock = makeApp({ analyzer: createAnalyzer(loadConfig({})) });
    const res = await postAnalyze(mock.app, body);
    expect(res.statusCode).toBe(200);
    expect(res.json().source).toBe('mock');
  });

  it('/health stays 200 and makes no provider claim when nvidia is selected', async () => {
    const { app, calls } = nvidiaApp(() => chat(modelJSON()));
    const res = await app.inject({ method: 'GET', url: '/health' });
    expect(res.statusCode).toBe(200);
    expect(Object.keys(res.json()).sort()).toEqual(['service', 'status', 'time', 'version']);
    expect(calls).toHaveLength(0);
  });
});
