import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import type { ErrorObject } from 'ajv';
import { validators } from '../contracts.js';
import { sendError } from '../middleware/errors.js';
import { classifyRisk } from '../risk/classify.js';
import type { RiskAnalyzer } from '../risk/RiskAnalyzer.js';
import type { AnalyzeRequest, RiskAssessment } from '../risk/types.js';

/** Trims string fields and drops empty optional strings, per contract. Non-objects pass through to fail validation. */
export function normalizeRequest(body: unknown): unknown {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return body;
  const out: Record<string, unknown> = { ...(body as Record<string, unknown>) };
  for (const key of ['content', 'phoneNumber', 'context']) {
    if (typeof out[key] === 'string') out[key] = (out[key] as string).trim();
  }
  for (const key of ['phoneNumber', 'context']) {
    if (out[key] === '') delete out[key];
  }
  return out;
}

/** Builds a safe message from schema field names only; never includes submitted values or unknown keys. */
function validationMessage(errors: ErrorObject[] | null | undefined): string {
  const first = errors?.[0];
  if (!first) return 'Please provide a supported kind and non-empty content.';
  if (first.keyword === 'additionalProperties') return 'The request contains fields that are not allowed.';
  if (first.keyword === 'required') return `The "${String(first.params.missingProperty)}" field is required.`;
  const field = first.instancePath.replace(/^\//, '');
  return field ? `The "${field}" field is missing or invalid.` : 'Please provide a supported kind and non-empty content.';
}

export function analyzeRoutes(analyzer: RiskAnalyzer) {
  return async (app: FastifyInstance) => {
    app.post('/api/v1/analyze', async (request, reply) => {
      const body = normalizeRequest(request.body);
      if (!validators.analyzeRequest(body)) {
        return sendError(reply, 400, 'VALIDATION_ERROR', validationMessage(validators.analyzeRequest.errors));
      }
      const req = body as AnalyzeRequest;
      const result = await analyzer.analyze(req, { log: request.log });
      // Provider isolation: a result may only carry its own analyzer's source (no relabelling).
      if (result?.source !== analyzer.provider) {
        throw new Error('analyzer returned a source that does not match its provider');
      }

      // riskLevel is always derived here, never trusted from the analyzer. Throws on a bad score.
      const assessment: RiskAssessment = {
        analysisId: randomUUID(),
        kind: req.kind,
        riskScore: result.riskScore,
        riskLevel: classifyRisk(result.riskScore),
        summary: result.summary,
        signals: result.signals,
        recommendedActions: result.recommendedActions,
        source: result.source,
        requiresHumanReview: result.requiresHumanReview,
        analyzedAt: new Date().toISOString(),
      };
      if (!validators.riskAssessment(assessment)) {
        throw new Error('analyzer produced a response that violates the contract');
      }
      return assessment;
    });
  };
}
