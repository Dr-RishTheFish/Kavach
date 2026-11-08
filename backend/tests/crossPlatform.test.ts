import { existsSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { validators } from '../src/contracts.js';

// L3: the iOS app keeps its own copy of the canonical response for its unit tests.
// It must stay identical to shared/contracts/examples/analyze-response.json.
const repo = (p: string) => new URL(`../../${p}`, import.meta.url);
const iosFixture = repo('ios/KavachTests/Fixtures/assessment.json');
const json = (u: URL) => JSON.parse(readFileSync(u, 'utf8'));

describe.skipIf(!existsSync(iosFixture))('iOS fixture parity', () => {
  it('iOS assessment.json deep-equals the canonical analyze-response example', () => {
    expect(json(iosFixture)).toEqual(json(repo('shared/contracts/examples/analyze-response.json')));
  });

  it('iOS assessment.json satisfies the canonical response schema', () => {
    expect(validators.riskAssessment(json(iosFixture)), JSON.stringify(validators.riskAssessment.errors)).toBe(true);
  });
});
