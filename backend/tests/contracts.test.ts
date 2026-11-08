import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { validators } from '../src/contracts.js';

const example = (name: string) =>
  JSON.parse(readFileSync(new URL(`../../shared/contracts/examples/${name}`, import.meta.url), 'utf8'));

describe('shared/contracts examples', () => {
  it.each([
    ['analyze-request.json', 'analyzeRequest'],
    ['analyze-response.json', 'riskAssessment'],
    ['analyze-error.json', 'error'],
    ['health.json', 'health'],
  ] as const)('%s satisfies its schema', (file, key) => {
    const validate = validators[key];
    expect(validate(example(file)), JSON.stringify(validate.errors)).toBe(true);
  });
});

describe('schema rules', () => {
  const okResponse = example('analyze-response.json');

  it('rejects a riskLevel that does not match riskScore', () => {
    expect(validators.riskAssessment({ ...okResponse, riskScore: 10 })).toBe(false);
  });

  it('rejects an unknown riskLevel such as "unknown"', () => {
    expect(validators.riskAssessment({ ...okResponse, riskLevel: 'unknown' })).toBe(false);
  });

  it('rejects a reportId (analysis is not a saved report)', () => {
    expect(validators.riskAssessment({ ...okResponse, reportId: 'r1' })).toBe(false);
  });

  it.each([
    [{ kind: 'unknown', content: 'x' }],
    [{ kind: 'call' }],
    [{ kind: 'call', content: '' }],
    [{ kind: 'call', content: 'x', extra: true }],
    [{ kind: 'call', content: 'x', phoneNumber: '202-555-0123' }],
    [{ kind: 'call', content: 'x', phoneNumber: '+1234567890123456' }],
    [{ kind: 'call', content: 'x'.repeat(5001) }],
    [{ kind: 'call', content: 'x', context: 'y'.repeat(1001) }],
  ])('rejects invalid request %j', body => {
    expect(validators.analyzeRequest(body)).toBe(false);
  });

  it('counts content length in Unicode code points, not UTF-16 units', () => {
    expect(validators.analyzeRequest({ kind: 'sms', content: '🙂'.repeat(5000) })).toBe(true);
  });
});
