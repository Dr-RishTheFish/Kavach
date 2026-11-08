import type { RiskLevel } from './types.js';

/** Contract mapping (non-negotiable): 0-24 low, 25-49 guarded, 50-74 high, 75-100 critical. */
export function classifyRisk(score: number): RiskLevel {
  if (!Number.isInteger(score) || score < 0 || score > 100) {
    throw new RangeError('riskScore must be an integer from 0 to 100');
  }
  if (score <= 24) return 'low';
  if (score <= 49) return 'guarded';
  if (score <= 74) return 'high';
  return 'critical';
}
