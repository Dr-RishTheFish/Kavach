// Mirrors shared/contracts/*.schema.json (contract v0.1.0). The JSON Schemas are canonical.
export const KINDS = ['call', 'sms', 'message', 'url'] as const;
export type Kind = (typeof KINDS)[number];

export type RiskLevel = 'low' | 'guarded' | 'high' | 'critical';
export type AnalysisSource = 'mock' | 'nvidia';

/** A request that has already been trimmed and validated against analyze-request.schema.json. */
export interface AnalyzeRequest {
  kind: Kind;
  content: string;
  phoneNumber?: string;
  context?: string;
}

/** What an analyzer produces. The route adds id, kind, derived riskLevel and timestamp. */
export interface AnalyzerResult {
  riskScore: number;
  summary: string;
  signals: string[];
  recommendedActions: string[];
  source: AnalysisSource;
  requiresHumanReview: boolean;
}

export interface RiskAssessment extends AnalyzerResult {
  analysisId: string;
  kind: Kind;
  riskLevel: RiskLevel;
  analyzedAt: string;
}
