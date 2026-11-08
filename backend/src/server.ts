import { buildApp } from './app.js';
import { loadConfig } from './config.js';

const config = loadConfig();
const app = buildApp({ bodyLimitBytes: config.bodyLimitBytes });

if (config.host !== '127.0.0.1' && config.host !== 'localhost' && config.host !== '::1') {
  app.log.warn('HOST is not loopback: the API is reachable from your network over plain HTTP. Development only.');
}

const shutdown = async (signal: string) => {
  app.log.info({ signal }, 'shutting down');
  await app.close();
  process.exit(0);
};
process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));

try {
  await app.listen({ host: config.host, port: config.port });
  app.log.info({ analysisProvider: config.analysisProvider }, 'kavach-api ready (Module 0, mock analyzer)');
} catch (err) {
  app.log.error({ errName: (err as Error).name, errCode: (err as { code?: string }).code ?? null }, 'failed to start');
  process.exit(1);
}
