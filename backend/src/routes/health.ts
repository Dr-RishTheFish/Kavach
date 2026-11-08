import type { FastifyInstance } from 'fastify';
import { API_VERSION, SERVICE_NAME } from '../version.js';

/** Liveness only: does not check NVIDIA, Photon or SpacetimeDB. */
export async function healthRoutes(app: FastifyInstance) {
  app.get('/health', async () => ({
    status: 'ok',
    service: SERVICE_NAME,
    version: API_VERSION,
    time: new Date().toISOString(),
  }));
}
