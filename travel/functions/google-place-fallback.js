import { createHash } from 'node:crypto';
import { HttpError } from './endpoint-security.js';

// Deployment opt-in and secret binding are both required. No bulk/photo path.
export async function googlePlaceFallback(database, uid, body, {apiKey, enabled = false, fetchImpl = fetch} = {}) {
  if (!enabled || !apiKey) throw new HttpError(403, 'Google fallback is disabled.');
  const query = typeof body.query === 'string' ? body.query.trim() : '';
  if (body.userRequested !== true || query.length < 3 || query.length > 150) {
    throw new HttpError(400, 'An explicit place search is required.');
  }
  const globalRef = database.collection('placeUsage').doc('google-fallback');
  const userRef = database.collection('placeUsage').doc('google-' + createHash('sha256').update(uid).digest('hex'));
  await database.runTransaction(async tx => {
    const day = Math.floor(Date.now() / 86400000);
    const [global, user] = await Promise.all([tx.get(globalRef), tx.get(userRef)]);
    const count = snapshot => snapshot.data()?.day === day ? snapshot.data().count ?? 0 : 0;
    if (count(global) >= 10 || count(user) >= 2) throw new HttpError(429, 'Google search allowance used for today.');
    tx.set(globalRef, {day, count: count(global) + 1});
    tx.set(userRef, {day, count: count(user) + 1});
  });
  const response = await fetchImpl('https://places.googleapis.com/v1/places:searchText', {
    method: 'POST', headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.types'},
    body: JSON.stringify({textQuery: query, maxResultCount: 3}), signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new HttpError(503, 'Google search unavailable.');
  const data = await response.json();
  return (data.places ?? []).filter(p => Number.isFinite(p.location?.latitude) && Number.isFinite(p.location?.longitude))
    .map(p => ({id: `google:${p.id}`, name: p.displayName?.text ?? '', address: p.formattedAddress ?? '',
      latitude: p.location.latitude, longitude: p.location.longitude, types: p.types ?? [], source: 'google'}));
}
