// Simulated NVIDIA transport for offline tests. Never touches the network.
export interface Call { url: string; init: RequestInit; body: Record<string, any> }

export function fakeFetch(handler: (call: Call) => Response | Promise<Response>) {
  const calls: Call[] = [];
  const fn = (async (input: string | URL | Request, init: RequestInit = {}) => {
    const call = { url: String(input), init, body: JSON.parse(String(init.body ?? '{}')) };
    calls.push(call);
    return handler(call);
  }) as typeof fetch;
  return { fetch: fn, calls };
}

/** An OpenAI-compatible chat completion response wrapping `content`. */
export function chat(content: unknown, finishReason = 'stop', status = 200): Response {
  return new Response(
    JSON.stringify({ id: 'cmpl-test', choices: [{ index: 0, message: { role: 'assistant', content }, finish_reason: finishReason }] }),
    { status, headers: { 'content-type': 'application/json' } },
  );
}

export const modelJSON = (overrides: Record<string, unknown> = {}) =>
  JSON.stringify({
    riskScore: 92,
    summary: 'The caller claims to be a bank and pressures an urgent transfer.',
    signals: ['Claims to represent a bank', 'Pressures an urgent money transfer'],
    recommendedActions: ['Do not transfer money', 'Call your bank using an independently verified number'],
    requiresHumanReview: false,
    ...overrides,
  });

export const config = { apiKey: 'nvapi-TEST-KEY-123', model: 'vendor/test-model', baseUrl: 'https://nim.example.invalid/v1', timeoutMs: 2000 };
