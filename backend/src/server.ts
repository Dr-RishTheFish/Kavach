import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { createAnalyzer } from './risk/createAnalyzer.js';

const config = loadConfig();
const app = buildApp({ bodyLimitBytes: config.bodyLimitBytes, analyzer: createAnalyzer(config) });

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
  const live = config.nvidia;
  app.log.info(
    {
      analysisProvider: config.analysisProvider,
      ...(live ? { nvidiaModel: live.model || null, nvidiaKeyPresent: live.apiKey !== '', nvidiaBaseUrl: live.baseUrl } : {}),
    },
    'kavach-api ready',
  );
  if (live && (!live.apiKey || !live.model)) {
    app.log.warn('ANALYSIS_PROVIDER=nvidia but NVIDIA_API_KEY or NVIDIA_MODEL is missing: /api/v1/analyze will return 503');
  }
} catch (err) {
  app.log.error({ errName: (err as Error).name, errCode: (err as { code?: string }).code ?? null }, 'failed to start');
  process.exit(1);
}
