import { describe, expect, it } from 'vitest';
import { classifyRisk } from '../src/risk/classify.js';

describe('classifyRisk', () => {
  it.each([
    [0, 'low'], [24, 'low'],
    [25, 'guarded'], [49, 'guarded'],
    [50, 'high'], [74, 'high'],
    [75, 'critical'], [100, 'critical'],
  ] as const)('maps score %i to %s', (score, level) => {
    expect(classifyRisk(score)).toBe(level);
  });

  it.each([-1, 101, 50.5, Number.NaN])('rejects out-of-contract score %s', score => {
    expect(() => classifyRisk(score)).toThrow(RangeError);
  });
});
