import test from 'node:test';
import assert from 'node:assert/strict';
import {groqJson} from '../groq-provider.js';

const request = {apiKey: ' fictional-key\r\n', name: 'trip_ai_command',
  schema: {type: 'object'}, instruction: 'Return JSON', input: 'fictional trip'};

test('cloud Groq adapter sends server credentials and bounded structured output', async () => {
  const result = await groqJson({...request, fetchImpl: async (url, options) => {
    assert.equal(url, 'https://api.groq.com/openai/v1/chat/completions');
    assert.equal(options.headers.Authorization, 'Bearer fictional-key');
    assert.ok(options.signal instanceof AbortSignal);
    const body = JSON.parse(options.body);
    assert.equal(body.max_completion_tokens, 4096);
    assert.equal(body.response_format.json_schema.strict, true);
    assert.equal(body.messages[1].content, request.input);
    return {ok: true, json: async () => ({choices: [{message: {content: '{"ok":true}'}}]})};
  }});
  assert.deepEqual(result, {ok: true});
});

for (const [status, expected] of [[429, 429], [401, 503], [403, 503], [500, 502]]) {
  test(`provider status ${status} produces a safe error without reading raw body`, async () => {
    await assert.rejects(groqJson({...request, fetchImpl: async () => ({
      ok: false, status,
      text: async () => {throw new Error('Must not read sensitive error body');},
    })}), error => error.status === expected && !error.message.includes('fictional-key'));
  });
}

test('network failure returns a recoverable error', async () => {
  await assert.rejects(groqJson({...request, fetchImpl: async () => {
    throw new Error('sensitive network details');
  }}), error => error.status === 503 && !error.message.includes('sensitive'));
});

for (const choice of [{message: {content: 'not JSON'}},
  {finish_reason: 'length', message: {content: '{}'}}]) {
  test(`rejects ${choice.finish_reason ?? 'malformed'} response`, async () => {
    await assert.rejects(groqJson({...request, fetchImpl: async () => ({
      ok: true, json: async () => ({choices: [choice]}),
    })}), error => error.status === 502);
  });
}

test('missing key never makes a provider request', async () => {
  await assert.rejects(groqJson({...request, apiKey: ' ', fetchImpl: async () => {
    assert.fail('must not fetch');
  }}), error => error.status === 503);
});
