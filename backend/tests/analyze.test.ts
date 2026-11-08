import { describe, expect, it } from 'vitest';
import { validators } from '../src/contracts.js';
import { classifyRisk } from '../src/risk/classify.js';
import type { RiskAnalyzer } from '../src/risk/RiskAnalyzer.js';
import { makeApp, postAnalyze } from './helpers.js';

const expectError = (res: Awaited<ReturnType<typeof postAnalyze>>, status: number, code: string) => {
  expect(res.statusCode).toBe(status);
  const body = res.json();
  expect(validators.error(body), JSON.stringify(validators.error.errors)).toBe(true);
  expect(body.error.code).toBe(code);
  expect(body.error.requestId).toBe(res.headers['x-request-id']);
  return body;
};

describe('POST /api/v1/analyze success', () => {
  const { app } = makeApp();

  it('returns a schema-valid mock assessment with derived riskLevel', async () => {
    const res = await postAnalyze(app, {
      kind: 'call',
      content: 'A caller claimed to be my bank and urgently requested a transfer.',
      phoneNumber: '+12025550123',
      context: 'I did not initiate the call.',
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(validators.riskAssessment(body), JSON.stringify(validators.riskAssessment.errors)).toBe(true);
    expect(body.source).toBe('mock');
    expect(body.kind).toBe('call');
    expect(body.riskLevel).toBe(classifyRisk(body.riskScore));
    expect(body.riskLevel).toBe('critical');
    expect(body).not.toHaveProperty('reportId');
  });

  it('issues a fresh analysisId per request', async () => {
    const a = (await postAnalyze(app, { kind: 'sms', content: 'hello' })).json();
    const b = (await postAnalyze(app, { kind: 'sms', content: 'hello' })).json();
    expect(a.analysisId).not.toBe(b.analysisId);
  });

  it('accepts a request without optional fields', async () => {
    expect((await postAnalyze(app, { kind: 'url', content: 'Delivery failed, pay a small fee at this link' })).statusCode).toBe(200);
  });

  it('treats empty optional strings as absent', async () => {
    expect((await postAnalyze(app, { kind: 'message', content: 'hi', phoneNumber: '', context: '  ' })).statusCode).toBe(200);
  });

  it('trims content before enforcing the 5000 character limit', async () => {
    expect((await postAnalyze(app, { kind: 'sms', content: `  ${'a'.repeat(5000)}  ` })).statusCode).toBe(200);
  });

  it('accepts application/json with a charset parameter', async () => {
    const res = await postAnalyze(app, { kind: 'sms', content: 'hi' }, { 'content-type': 'application/json; charset=utf-8' });
    expect(res.statusCode).toBe(200);
  });
});

describe('POST /api/v1/analyze validation errors', () => {
  const { app } = makeApp();

  it.each([
    ['unsupported kind', { kind: 'unknown', content: 'test' }],
    ['missing content', { kind: 'call' }],
    ['blank content', { kind: 'call', content: '   ' }],
    ['content wrong type', { kind: 'call', content: 42 }],
    ['kind wrong type', { kind: ['call'], content: 'x' }],
    ['unexpected property', { kind: 'call', content: 'x', reportId: 'r1' }],
    ['invalid phone number', { kind: 'call', content: 'x', phoneNumber: '555-0123' }],
    ['content too long', { kind: 'call', content: 'a'.repeat(5001) }],
    ['context too long', { kind: 'call', content: 'x', context: 'c'.repeat(1001) }],
    ['array body', [{ kind: 'call', content: 'x' }]],
    ['null body', null],
  ])('%s -> 400 VALIDATION_ERROR', async (_name, payload) => {
    expectError(await postAnalyze(app, payload), 400, 'VALIDATION_ERROR');
  });

  it('bad JSON -> 400 INVALID_JSON', async () => {
    expectError(await postAnalyze(app, '{"kind": "call", '), 400, 'INVALID_JSON');
  });

  it('body over 32 KiB -> 413 PAYLOAD_TOO_LARGE', async () => {
    expectError(await postAnalyze(app, { kind: 'call', content: 'a'.repeat(40_000) }), 413, 'PAYLOAD_TOO_LARGE');
  });

  it('non-JSON content type -> 415 UNSUPPORTED_MEDIA_TYPE', async () => {
    const res = await app.inject({ method: 'POST', url: '/api/v1/analyze', headers: { 'content-type': 'text/plain' }, payload: 'hi' });
    expectError(res, 415, 'UNSUPPORTED_MEDIA_TYPE');
  });

  it('unknown route -> 404 NOT_FOUND envelope', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/v1/nope' });
    expectError(res, 404, 'NOT_FOUND');
  });

  it('error messages never contain user-supplied text', async () => {
    const body = expectError(await postAnalyze(app, { kind: 'MARKER-KIND-77', content: 'MARKER-CONTENT-77' }), 400, 'VALIDATION_ERROR');
    expect(JSON.stringify(body)).not.toContain('MARKER');
  });
});

describe('POST /api/v1/analyze fails safely on analyzer bugs', () => {
  const broken = (result: unknown): RiskAnalyzer => ({ analyze: async () => result as never });

  it.each([
    ['score out of range', { riskScore: 150, summary: 's', signals: [], recommendedActions: ['a'], source: 'mock', requiresHumanReview: false }],
    ['non-integer score', { riskScore: 50.5, summary: 's', signals: [], recommendedActions: ['a'], source: 'mock', requiresHumanReview: false }],
    ['missing summary', { riskScore: 10, signals: [], recommendedActions: ['a'], source: 'mock', requiresHumanReview: false }],
    ['bogus source', { riskScore: 10, summary: 's', signals: [], recommendedActions: ['a'], source: 'gpt', requiresHumanReview: false }],
  ])('%s -> 500 INTERNAL_ERROR', async (_name, result) => {
    const { app } = makeApp({ analyzer: broken(result) });
    expectError(await postAnalyze(app, { kind: 'call', content: 'x' }), 500, 'INTERNAL_ERROR');
  });

  it('analyzer exception -> 500 without a stack trace', async () => {
    const { app } = makeApp({ analyzer: { analyze: async () => { throw new Error('boom at /secret/path'); } } });
    const body = expectError(await postAnalyze(app, { kind: 'call', content: 'x' }), 500, 'INTERNAL_ERROR');
    expect(JSON.stringify(body)).not.toMatch(/boom|secret|stack/);
  });
});

describe('logging redaction', () => {
  it('logs request ids and status but never content, context, phone numbers or auth headers', async () => {
    const { app, logs } = makeApp();
    const res = await postAnalyze(
      app,
      { kind: 'call', content: 'SENSITIVE-CONTENT tell me the code', phoneNumber: '+12025550199', context: 'SENSITIVE-CONTEXT' },
      { authorization: 'Bearer SENSITIVE-TOKEN' },
    );
    await postAnalyze(app, '{"kind":"call","content":"SENSITIVE-BADJSON');
    await app.inject({ method: 'GET', url: '/health?token=SENSITIVE-QUERY' });
    const text = logs();
    expect(text).toContain(String(res.headers['x-request-id']));
    expect(text).toContain('"statusCode":200');
    for (const secret of ['SENSITIVE', '2025550199']) expect(text).not.toContain(secret);
  });
});
