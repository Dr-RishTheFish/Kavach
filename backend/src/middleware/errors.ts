import type { FastifyError, FastifyReply, FastifyRequest } from 'fastify';

export type ErrorCode =
  | 'INVALID_JSON'
  | 'VALIDATION_ERROR'
  | 'PAYLOAD_TOO_LARGE'
  | 'UNSUPPORTED_MEDIA_TYPE'
  | 'NOT_FOUND'
  | 'INTERNAL_ERROR'
  | 'ANALYZER_UNAVAILABLE';

/** Sends the contract error envelope. `message` must be a fixed, safe string, never user text. */
export function sendError(reply: FastifyReply, status: number, code: ErrorCode, message: string) {
  return reply.status(status).send({ error: { code, message, requestId: String(reply.request.id) } });
}

/** Maps framework/parser errors to contract codes. Never forwards err.message or stacks. */
export function errorHandler(err: FastifyError, request: FastifyRequest, reply: FastifyReply) {
  switch (err.code) {
    case 'FST_ERR_CTP_BODY_TOO_LARGE':
      return sendError(reply, 413, 'PAYLOAD_TOO_LARGE', 'The request body is too large.');
    case 'FST_ERR_CTP_INVALID_MEDIA_TYPE':
      return sendError(reply, 415, 'UNSUPPORTED_MEDIA_TYPE', 'Send the request body as application/json.');
    case 'FST_ERR_CTP_EMPTY_JSON_BODY':
      return sendError(reply, 400, 'VALIDATION_ERROR', 'Please provide a supported kind and non-empty content.');
  }
  if (err.statusCode === 400 && (err instanceof SyntaxError || err.code === 'FST_ERR_CTP_INVALID_JSON_BODY')) {
    return sendError(reply, 400, 'INVALID_JSON', 'The request body is not valid JSON.');
  }
  // Log only the error class/code: messages from parsers or analyzers could quote user input.
  request.log.error({ errName: err.name, errCode: err.code ?? null }, 'request failed');
  return sendError(reply, 500, 'INTERNAL_ERROR', 'Something went wrong. Please try again.');
}
