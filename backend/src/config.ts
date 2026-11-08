export interface Config {
  host: string;
  port: number;
  analysisProvider: 'mock';
  bodyLimitBytes: number;
}

type Env = Record<string, string | undefined>;

/** Reads only the variables it needs. Error messages never include env values. */
export function loadConfig(env: Env = process.env): Config {
  const host = env.HOST?.trim() || '127.0.0.1';

  const rawPort = env.PORT?.trim() || '3001';
  const port = Number(rawPort);
  if (!/^\d+$/.test(rawPort) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer from 1 to 65535');
  }

  const provider = env.ANALYSIS_PROVIDER?.trim() || 'mock';
  if (provider === 'nvidia') {
    throw new Error('ANALYSIS_PROVIDER=nvidia is not implemented until Module 1; use mock');
  }
  if (provider !== 'mock') {
    throw new Error('ANALYSIS_PROVIDER must be "mock" in Module 0');
  }

  return { host, port, analysisProvider: 'mock', bodyLimitBytes: 32 * 1024 };
}
