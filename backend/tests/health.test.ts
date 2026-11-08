import { afterEach, describe, expect, it } from 'vitest';
import { validators } from '../src/contracts.js';
import { makeApp } from './helpers.js';

describe('GET /health', () => {
  const { app } = makeApp();
  afterEach(() => undefined);

  it('returns 200 with the documented shape and a live UTC timestamp', async () => {
    const before = Date.now();
    const res = await app.inject({ method: 'GET', url: '/health' });
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toMatch(/^application\/json/);
    const body = res.json();
    expect(validators.health(body), JSON.stringify(validators.health.errors)).toBe(true);
    expect(body).toMatchObject({ status: 'ok', service: 'kavach-api', version: '0.1.0' });
    expect(body.time.endsWith('Z')).toBe(true);
    expect(Date.parse(body.time)).toBeGreaterThanOrEqual(before - 1000);
  });

  it('sets an x-request-id header', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' });
    expect(res.headers['x-request-id']).toBeTruthy();
  });
});
