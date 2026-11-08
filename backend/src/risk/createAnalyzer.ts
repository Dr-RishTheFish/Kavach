import type { Config } from '../config.js';
import { MockRiskAnalyzer } from './MockRiskAnalyzer.js';
import { NvidiaRiskAnalyzer } from './NvidiaRiskAnalyzer.js';
import type { RiskAnalyzer } from './RiskAnalyzer.js';

/** Server-side provider selection. `nvidia` never falls back to mock: if unusable, analyze returns 503. */
export function createAnalyzer(config: Config, transport?: typeof fetch): RiskAnalyzer {
  if (config.analysisProvider === 'nvidia' && config.nvidia) {
    return new NvidiaRiskAnalyzer({ ...config.nvidia, ...(transport ? { fetch: transport } : {}) });
  }
  return new MockRiskAnalyzer();
}
