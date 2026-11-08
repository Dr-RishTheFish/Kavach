import { describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';

describe('loadConfig', () => {
  it('defaults to loopback, port 3001 and the mock analyzer', () => {
    expect(loadConfig({})).toEqual({ host: '127.0.0.1', port: 3001, analysisProvider: 'mock', bodyLimitBytes: 32768 });
  });

  it('honours HOST and PORT overrides', () => {
    const cfg = loadConfig({ HOST: '0.0.0.0', PORT: '4000' });
    expect(cfg.host).toBe('0.0.0.0');
    expect(cfg.port).toBe(4000);
  });

  it.each(['abc', '0', '70000', '30.5'])('rejects invalid PORT %s', port => {
    expect(() => loadConfig({ PORT: port })).toThrow(/PORT/);
  });

  it.each(['openai', 'NVIDIA ', 'auto'])('rejects an unknown ANALYSIS_PROVIDER %j at startup', provider => {
    expect(() => loadConfig({ ANALYSIS_PROVIDER: provider })).toThrow(/ANALYSIS_PROVIDER/);
  });

  it('selects nvidia with server-side settings and the official default endpoint', () => {
    const cfg = loadConfig({ ANALYSIS_PROVIDER: 'nvidia', NVIDIA_API_KEY: 'nvapi-test', NVIDIA_MODEL: 'vendor/model-x' });
    expect(cfg.analysisProvider).toBe('nvidia');
    expect(cfg.nvidia).toEqual({
      apiKey: 'nvapi-test',
      model: 'vendor/model-x',
      baseUrl: 'https://integrate.api.nvidia.com/v1',
      timeoutMs: 15000,
      thinking: 'off',
    });
  });

  it('accepts NVIDIA_BASE_URL and NVIDIA_TIMEOUT_MS overrides', () => {
    const cfg = loadConfig({
      ANALYSIS_PROVIDER: 'nvidia', NVIDIA_API_KEY: 'k', NVIDIA_MODEL: 'm',
      NVIDIA_BASE_URL: 'https://example.invalid/v1/', NVIDIA_TIMEOUT_MS: '5000',
    });
    expect(cfg.nvidia?.baseUrl).toBe('https://example.invalid/v1');
    expect(cfg.nvidia?.timeoutMs).toBe(5000);
  });

  it('starts with nvidia selected but unconfigured, so analyze can fail closed with 503', () => {
    const cfg = loadConfig({ ANALYSIS_PROVIDER: 'nvidia' });
    expect(cfg.analysisProvider).toBe('nvidia');
    expect(cfg.nvidia).toMatchObject({ apiKey: '', model: '' });
  });

  it.each(['0', '-5', 'abc', '120001'])('rejects invalid NVIDIA_TIMEOUT_MS %s', timeout => {
    expect(() => loadConfig({ ANALYSIS_PROVIDER: 'nvidia', NVIDIA_TIMEOUT_MS: timeout })).toThrow(/NVIDIA_TIMEOUT_MS/);
  });

  it('rejects a non-https NVIDIA_BASE_URL so the key never travels in plaintext', () => {
    expect(() => loadConfig({ ANALYSIS_PROVIDER: 'nvidia', NVIDIA_BASE_URL: 'http://integrate.api.nvidia.com/v1' })).toThrow(/NVIDIA_BASE_URL/);
  });

  it('never echoes secret env values in errors', () => {
    let message = '';
    try {
      loadConfig({ ANALYSIS_PROVIDER: 'nvidia', NVIDIA_API_KEY: 'nvapi-SECRET-123', NVIDIA_TIMEOUT_MS: 'bad' });
    } catch (err) {
      message = String(err);
    }
    expect(message).toMatch(/NVIDIA_TIMEOUT_MS/);
    expect(message).not.toContain('SECRET');
  });

  it('accepts NVIDIA_THINKING=default and rejects unknown values', () => {
    expect(loadConfig({ ANALYSIS_PROVIDER: 'nvidia', NVIDIA_THINKING: 'default' }).nvidia?.thinking).toBe('default');
    expect(() => loadConfig({ ANALYSIS_PROVIDER: 'nvidia', NVIDIA_THINKING: 'on' })).toThrow(/NVIDIA_THINKING/);
  });

  it('does not expose nvidia settings when the mock provider is selected', () => {
    expect(loadConfig({ NVIDIA_API_KEY: 'nvapi-x' }).nvidia).toBeUndefined();
  });
});
