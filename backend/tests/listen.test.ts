import type { AddressInfo } from 'node:net';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { validators } from '../src/contracts.js';
import { makeApp } from './helpers.js';

// L2: the same contract over a real TCP socket (not fastify.inject), bound to loopback.
describe('real HTTP listener', () => {
  const { app } = makeApp();
  let base = '';

  beforeAll(async () => {
    await app.listen({ host: '127.0.0.1', port: 0 });
    const addr = app.server.address() as AddressInfo;
    expect(addr.address).toBe('127.0.0.1');
    base = `http://127.0.0.1:${addr.port}`;
  });
  afterAll(() => app.close());

  it('serves /health', async () => {
    const res = await fetch(`${base}/health`);
    expect(res.status).toBe(200);
    expect(validators.health(await res.json())).toBe(true);
  });

  it('round-trips a contract request exactly as the iOS client sends it', async () => {
    const res = await fetch(`${base}/api/v1/analyze`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8', Accept: 'application/json' },
      body: JSON.stringify({ kind: 'sms', content: 'Tell me the code we just texted you' }),
    });
    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toMatch(/^application\/json/);
    const body = await res.json();
    expect(validators.riskAssessment(body)).toBe(true);
    expect(body).toMatchObject({ kind: 'sms', riskLevel: 'critical', source: 'mock' });
  });

  it('returns the error envelope for a non-JSON body over the wire', async () => {
    const res = await fetch(`${base}/api/v1/analyze`, { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: 'x' });
    expect(res.status).toBe(415);
    const body = await res.json();
    expect(validators.error(body)).toBe(true);
    expect(body.error.requestId).toBe(res.headers.get('x-request-id'));
  });
});
