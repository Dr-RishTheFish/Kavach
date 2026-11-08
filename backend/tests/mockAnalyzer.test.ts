import { describe, expect, it } from 'vitest';
import { MockRiskAnalyzer } from '../src/risk/MockRiskAnalyzer.js';
import { classifyRisk } from '../src/risk/classify.js';
import type { AnalyzeRequest } from '../src/risk/types.js';

const analyzer = new MockRiskAnalyzer();
const run = (content: string, kind: AnalyzeRequest['kind'] = 'call') => analyzer.analyze({ kind, content });

describe('MockRiskAnalyzer required scenarios', () => {
  it.each([
    ['bank impersonation', 'I am from your bank, transfer money in ten minutes', 'critical'],
    ['one-time-code phishing', 'Tell me the code we just texted you', 'critical'],
    ['package fee link', 'Delivery failed, pay a small fee at this link', 'high'],
    ['ambiguous callback', 'An unknown number asked me to call them back', 'guarded'],
    ['benign plans', 'A friend confirmed our lunch plans', 'low'],
  ] as const)('%s -> %s', async (_name, content, level) => {
    const result = await run(content);
    expect(classifyRisk(result.riskScore)).toBe(level);
    expect(result.source).toBe('mock');
    expect(result.recommendedActions.length).toBeGreaterThan(0);
  });

  it('matches the contract example wording "My bank says to urgently wire money."', async () => {
    expect(classifyRisk((await run('My bank says to urgently wire money.')).riskScore)).toBe('critical');
  });
});

describe('MockRiskAnalyzer behaviour', () => {
  it('is deterministic for the same input', async () => {
    expect(await run('Tell me the code we just texted you')).toEqual(await run('Tell me the code we just texted you'));
  });

  it('returns a clearly mocked cautious result for unrecognised text', async () => {
    const result = await run('The weather was cloudy today.');
    expect(result.source).toBe('mock');
    expect(result.requiresHumanReview).toBe(true);
    expect(classifyRisk(result.riskScore)).toBe('guarded');
    expect(result.summary).toMatch(/demo|simulated/i);
  });

  // Regression (found by the live iOS round trip): "unrecognized" alone must not trigger the
  // unknown-callback rule; it needs an unfamiliar number/caller/contact or a callback request.
  it.each(['Unrecognized synthetic text about the weather', 'An unknown song played on the radio'])(
    'falls back to a flagged demo result for %s',
    async content => {
      const result = await run(content, 'message');
      expect(result.requiresHumanReview).toBe(true);
      expect(result.summary).toMatch(/simulated/i);
    },
  );

  it.each(['A private number called twice', 'An unfamiliar caller left a voicemail', 'Please call me back on this line'])(
    'still treats %s as an unsolicited contact',
    async content => {
      const result = await run(content);
      expect(classifyRisk(result.riskScore)).toBe('guarded');
      expect(result.requiresHumanReview).toBe(false);
    },
  );

  it('never echoes the submitted content back in its output', async () => {
    const content = 'Tell me the code 482913 we just texted you';
    expect(JSON.stringify(await run(content))).not.toContain('482913');
  });

  it('does not treat a benign word as low risk when a scam pattern is also present', async () => {
    const result = await run('My friend said the bank wants me to wire money now');
    expect(classifyRisk(result.riskScore)).toBe('critical');
  });
});
