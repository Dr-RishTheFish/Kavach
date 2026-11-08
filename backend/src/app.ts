import { randomUUID } from 'node:crypto';
import type { Writable } from 'node:stream';
import Fastify, { type FastifyError, type FastifyRequest } from 'fastify';
import { errorHandler, sendError } from './middleware/errors.js';
import { MockRiskAnalyzer } from './risk/MockRiskAnalyzer.js';
import type { RiskAnalyzer } from './risk/RiskAnalyzer.js';
import { analyzeRoutes } from './routes/analyze.js';
import { healthRoutes } from './routes/health.js';

export interface AppOptions {
  analyzer: RiskAnalyzer;
  bodyLimitBytes: number;
  logLevel: string;
  /** Where JSON logs go (defaults to stdout). Tests pass a sink to assert redaction. */
  logStream?: Writable;
}

/** Path without query string, so tokens in URLs never reach logs. */
const pathOnly = (url: string | undefined) => (url ?? '').split('?')[0];

export function buildApp(options: Partial<AppOptions> = {}) {
  const analyzer = options.analyzer ?? new MockRiskAnalyzer();

  const app = Fastify({
    bodyLimit: options.bodyLimitBytes ?? 32 * 1024,
    connectionTimeout: 10_000,
    requestTimeout: 15_000,
    genReqId: () => randomUUID(),
    requestIdHeader: false, // ignore client-supplied ids
    logger: {
      level: options.logLevel ?? 'info',
      ...(options.logStream ? { stream: options.logStream } : {}),
      // Allow-list serializers: no bodies, headers, query strings or remote addresses.
      serializers: {
        req: (req: FastifyRequest) => ({ id: req.id, method: req.method, path: pathOnly(req.url) }),
        res: (res: { statusCode: number }) => ({ statusCode: res.statusCode }),
        // Error messages/stacks can quote user input, so they are blanked out.
        err: (err: FastifyError) => ({ type: err.name, code: err.code, message: '[redacted]', stack: '' }),
      },
    },
  });

  app.addHook('onRequest', async (request, reply) => {
    reply.header('x-request-id', request.id);
  });
  app.removeContentTypeParser('text/plain'); // JSON only; anything else -> 415
  app.setErrorHandler(errorHandler);
  app.setNotFoundHandler((_request, reply) => sendError(reply, 404, 'NOT_FOUND', 'Route not found.'));

  app.register(healthRoutes);
  app.register(analyzeRoutes(analyzer));
  return app;
}
