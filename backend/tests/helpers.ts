import { Writable } from 'node:stream';
import { buildApp, type AppOptions } from '../src/app.js';

/** Builds the app with a log sink so tests can inspect exactly what would be logged. */
export function makeApp(options: Partial<AppOptions> = {}) {
  const lines: string[] = [];
  const logStream = new Writable({
    write(chunk, _enc, done) {
      lines.push(chunk.toString());
      done();
    },
  });
  const app = buildApp({ logStream, ...options });
  return { app, logs: () => lines.join('') };
}

export const postAnalyze = (app: ReturnType<typeof makeApp>['app'], payload: unknown, headers: Record<string, string> = {}) =>
  app.inject({
    method: 'POST',
    url: '/api/v1/analyze',
    headers: { 'content-type': 'application/json', ...headers },
    payload: typeof payload === 'string' ? payload : JSON.stringify(payload),
  });
