import type { AnalysisSource, AnalyzeRequest, AnalyzerResult } from './types.js';

/** Minimal logger shape (pino/Fastify compatible). Analyzers log operational metadata only. */
export interface AnalyzerLog {
  info(obj: object, msg?: string): void;
  warn(obj: object, msg?: string): void;
}

export interface AnalyzeContext {
  log?: AnalyzerLog;
}

/**
 * Interchangeable analysis provider. Implementations must treat request text as untrusted data,
 * must never fetch user-supplied URLs, and must return `source` equal to their `provider`.
 * The route rejects any result whose source differs (no silent relabelling).
 */
export interface RiskAnalyzer {
  readonly provider: AnalysisSource;
  analyze(request: AnalyzeRequest, context?: AnalyzeContext): Promise<AnalyzerResult>;
}

export type UnavailableReason =
  | 'not_configured'
  | 'auth'
  | 'rate_limited'
  | 'upstream_error'
  | 'timeout'
  | 'network'
  | 'invalid_output'
  | 'busy';

/**
 * Thrown when a live provider cannot produce a valid result. The route maps it to
 * 503 ANALYZER_UNAVAILABLE. The message is fixed per reason and never carries user text,
 * provider bodies or credentials.
 */
export class AnalyzerUnavailableError extends Error {
  readonly reason: UnavailableReason;
  readonly upstreamStatus?: number;

  constructor(reason: UnavailableReason, upstreamStatus?: number) {
    super(`analyzer unavailable: ${reason}`);
    this.name = 'AnalyzerUnavailableError';
    this.reason = reason;
    if (upstreamStatus !== undefined) this.upstreamStatus = upstreamStatus;
  }
}
