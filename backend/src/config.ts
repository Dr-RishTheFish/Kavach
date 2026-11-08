export type AnalysisProvider = 'mock' | 'nvidia';

export interface NvidiaConfig {
  /** Server-side only. Empty means "selected but not configured": analyze fails closed with 503. */
  apiKey: string;
  model: string;
  /** OpenAI-compatible base URL, without trailing slash. */
  baseUrl: string;
  timeoutMs: number;
  /** 'off' sends chat_template_kwargs.enable_thinking=false (faster, no truncation on reasoning models). */
  thinking: 'off' | 'default';
}

export interface Config {
  host: string;
  port: number;
  analysisProvider: AnalysisProvider;
  bodyLimitBytes: number;
  nvidia?: NvidiaConfig;
}

type Env = Record<string, string | undefined>;

export const DEFAULT_NVIDIA_BASE_URL = 'https://integrate.api.nvidia.com/v1';
const DEFAULT_NVIDIA_TIMEOUT_MS = 15_000;

/** Reads only the variables it needs. Error messages name variables but never include their values. */
export function loadConfig(env: Env = process.env): Config {
  const host = env.HOST?.trim() || '127.0.0.1';

  const rawPort = env.PORT?.trim() || '3001';
  const port = Number(rawPort);
  if (!/^\d+$/.test(rawPort) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer from 1 to 65535');
  }

  const provider = env.ANALYSIS_PROVIDER === undefined || env.ANALYSIS_PROVIDER === '' ? 'mock' : env.ANALYSIS_PROVIDER;
  const base = { host, port, bodyLimitBytes: 32 * 1024 };
  if (provider === 'mock') return { ...base, analysisProvider: 'mock' };
  if (provider !== 'nvidia') throw new Error('ANALYSIS_PROVIDER must be "mock" or "nvidia"');

  const rawTimeout = env.NVIDIA_TIMEOUT_MS?.trim() || String(DEFAULT_NVIDIA_TIMEOUT_MS);
  const timeoutMs = Number(rawTimeout);
  if (!/^\d+$/.test(rawTimeout) || timeoutMs < 1 || timeoutMs > 120_000) {
    throw new Error('NVIDIA_TIMEOUT_MS must be an integer from 1 to 120000');
  }

  const baseUrl = (env.NVIDIA_BASE_URL?.trim() || DEFAULT_NVIDIA_BASE_URL).replace(/\/+$/, '');
  let parsed: URL;
  try {
    parsed = new URL(baseUrl);
  } catch {
    throw new Error('NVIDIA_BASE_URL must be a valid https URL');
  }
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password) {
    throw new Error('NVIDIA_BASE_URL must be a valid https URL');
  }

  const thinking = env.NVIDIA_THINKING?.trim() || 'off';
  if (thinking !== 'off' && thinking !== 'default') {
    throw new Error('NVIDIA_THINKING must be "off" or "default"');
  }

  return {
    ...base,
    analysisProvider: 'nvidia',
    nvidia: {
      apiKey: env.NVIDIA_API_KEY?.trim() ?? '',
      model: env.NVIDIA_MODEL?.trim() ?? '',
      baseUrl,
      timeoutMs,
      thinking,
    },
  };
}
