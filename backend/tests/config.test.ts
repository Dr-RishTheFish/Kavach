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

  it('refuses the nvidia provider until Module 1 implements it', () => {
    expect(() => loadConfig({ ANALYSIS_PROVIDER: 'nvidia' })).toThrow(/not implemented/i);
  });

  it('never echoes secret env values in errors', () => {
    try {
      loadConfig({ ANALYSIS_PROVIDER: 'nvidia', NVIDIA_API_KEY: 'nvapi-SECRET-123' });
    } catch (err) {
      expect(String(err)).not.toContain('SECRET');
    }
  });
});
