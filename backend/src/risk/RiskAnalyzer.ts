import type { AnalyzeRequest, AnalyzerResult } from './types.js';

/**
 * Interchangeable analysis provider. Module 0 ships MockRiskAnalyzer only; Module 1 adds an
 * NVIDIA-backed implementation behind this same interface. Implementations must treat
 * request text as untrusted data and must never fetch user-supplied URLs.
 */
export interface RiskAnalyzer {
  analyze(request: AnalyzeRequest): Promise<AnalyzerResult>;
}
