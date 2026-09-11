import test from 'node:test';
import assert from 'node:assert/strict';
import {authenticatedUser, consumeAiQuota} from './endpoint-security.js';
import {contextError} from './trip-command.js';
import {validateImportText, validateImportResult} from './itinerary-import.js';

test('rejects absent, invalid, revoked and unverified credentials', async () => {
  const request = {headers: {authorization: 'Bearer test'}};
  await assert.rejects(authenticatedUser({headers: {}}, {}), {status: 401});
  await assert.rejects(authenticatedUser(request, {verifyIdToken: async () => {throw Error('revoked');}}), {status: 401});
  await assert.rejects(authenticatedUser(request, {verifyIdToken: async () => ({uid: 'u', email_verified: false})}), {status: 403});
  assert.equal(await authenticatedUser(request, {verifyIdToken: async (_, revoked) => {
    assert.equal(revoked, true); return {uid: 'u', email_verified: true};
  }}), 'u');
});

test('per-account quota resets each minute, caps the day, and isolates accounts', async () => {
  const records = new Map();
  const db = {collection: () => ({doc: id => id}), runTransaction: async run => run({
    get: async ref => ({data: () => records.get(ref)}), set: (ref, value) => records.set(ref, value),
  })};
  for (let i = 0; i < 10; i++) await consumeAiQuota(db, 'u', 0);
  await assert.rejects(consumeAiQuota(db, 'u', 0), {status: 429});
  await consumeAiQuota(db, 'other', 0);
  for (let minute = 1; minute < 10; minute++) {
    for (let i = 0; i < 10; i++) await consumeAiQuota(db, 'u', minute * 60000);
  }
  await assert.rejects(consumeAiQuota(db, 'u', 600000), {status: 429});
  await consumeAiQuota(db, 'u', 86400000);
});

test('context validation rejects oversized and non-object input', () => {
  for (const value of [null, [], 'text', {notes: 'x'.repeat(1000000)}]) assert.ok(contextError(value));
  assert.equal(contextError({destinationId: 'trip'}), null);
});

test('import rejects oversized text and unsupported invented details', () => {
  for (const value of [null, {}, '', 'x'.repeat(20001)]) assert.throws(() => validateImportText(value), {status: 400});
  const source = '2026-09-10 08:30 Airport pickup';
  const result = validateImportResult({items: [{name: 'Airport pickup', date: '2026-09-10', time: '08:30', reference: 'FAKE123', address: 'Invented airport', sourceText: source}]}, source);
  assert.equal(result.items[0].reference, '');
  assert.equal(result.items[0].address, '');
  assert.equal(result.items[0].time, '08:30');
  assert.ok(result.items[0].warnings.length >= 2);
  assert.throws(() => validateImportResult({items: [{sourceText: 'not in the source'}]}, source), {status: 502});
});

test('import preserves ambiguous dates as unknown rather than normalizing guesses', () => {
  const source = 'Flight 09/10 at 8pm ref XYZ';
  const result = validateImportResult({items: [{name: 'Flight', date: '09/10', time: '8pm', reference: 'XYZ', sourceText: source}]}, source);
  assert.equal(result.items[0].date, ''); assert.equal(result.items[0].time, '');
  assert.equal(result.items[0].reference, 'XYZ');
});
