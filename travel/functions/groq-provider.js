import { HttpError } from './endpoint-security.js';

// Keys stay on the server. Never log provider bodies: they may echo user input.
export async function groqJson({apiKey, name, schema, instruction, input,
  fetchImpl = fetch, model = process.env.GROQ_MODEL || 'openai/gpt-oss-120b'}) {
  if (!apiKey?.trim()) throw new HttpError(503, 'AI is not configured.');
  let response;
  try {
    response = await fetchImpl('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST', signal: AbortSignal.timeout(25000),
      headers: {Authorization: `Bearer ${apiKey.trim()}`, 'Content-Type': 'application/json'},
      body: JSON.stringify({model, temperature: 0, include_reasoning: false,
        max_completion_tokens: 4096,
        response_format: {type: 'json_schema', json_schema: {name, strict: true, schema}},
        messages: [{role: 'system', content: instruction}, {role: 'user', content: input}],
      }),
    });
  } catch {
    throw new HttpError(503, 'AI did not respond. Please try again later.');
  }
  if (!response.ok) {
    // Safe diagnostic: status only, never raw errors, credentials or trip text.
    console.warn('Groq provider status', response.status);
    if (response.status === 429) throw new HttpError(429, 'AI capacity reached. Please try again later.');
    if ([401, 403].includes(response.status)) throw new HttpError(503, 'AI configuration needs attention. Please try again later.');
    throw new HttpError(502, 'AI could not process this request. Please try again later.');
  }
  try {
    const body = await response.json();
    const choice = body.choices?.[0];
    if (choice?.finish_reason === 'length') throw new Error('Truncated');
    return JSON.parse(choice?.message?.content);
  } catch {
    throw new HttpError(502, 'AI returned an incomplete response. Try a shorter request.');
  }
}
