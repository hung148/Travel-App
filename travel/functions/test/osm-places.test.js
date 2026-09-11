import test from 'node:test';
import assert from 'node:assert/strict';
import {osmRequest, normalizeElements, createOsmProvider, consumePlaceQuota} from '../osm-places.js';
import {googlePlaceFallback} from '../google-place-fallback.js';

function database() {
  const values = new Map();
  return {values, collection: name => ({doc: id => {
    const key = `${name}/${id}`;
    return {key, get: async () => ({data: () => values.get(key)}),
      set: async value => values.set(key, value),
      update: async value => values.set(key, {...values.get(key), ...value})};
  }}), runTransaction: async action => action({get: ref => ref.get(), set: (ref, value) => ref.set(value)})};
}
const elements = [{type: 'node', id: 1, lat: 16, lon: 108, tags: {name: 'Museum', tourism: 'museum'}},
  {type: 'way', id: 2, center: {lat: 16.01, lon: 108.01}, tags: {name: 'Market', amenity: 'marketplace'}}];

test('bounded requests reject arbitrary QL, invalid coordinates and oversized areas', () => {
  for (const body of [{action: 'area', latitude: NaN, longitude: 1, radius: 1000},
    {action: 'area', latitude: 1, longitude: 1, radius: 50000}, {action: 'details', id: 'node(1);out;'},
    {action: 'search', query: 'a'.repeat(101)}]) assert.throws(() => osmRequest(body));
  assert.match(osmRequest({action: 'search', query: 'Da Nang'}).query, /name:en/);
  assert.match(osmRequest({action: 'search', query: 'Da Nang'}).query, /out body 10/);
  assert.match(osmRequest({action: 'area', latitude: 16, longitude: 108, radius: 1000}).query, /out center tags 500/);
});
test('OSM identity, area centers and categories survive without invented ratings or photos', () => {
  const places = normalizeElements([...elements, elements[0], {type: 'node', id: 3, tags: {name: 'No coordinates'}}]);
  assert.equal(places.length, 2);
  assert.equal(places[1].id, 'osm:way:2');
  assert.deepEqual(places[1].types, ['market']);
  assert.equal(places[0].rating, undefined);
  assert.equal(places[0].photoUrls, undefined);
});
test('concurrent identical requests and later requests use one upstream call', async () => {
  const db = database(); let calls = 0;
  const lookup = createOsmProvider({fetchImpl: async url => {
    assert.match(url, /overpass/); calls++;
    return {ok: true, json: async () => ({elements})};
  }});
  const body = {action: 'area', latitude: 16, longitude: 108, radius: 1000};
  const results = await Promise.all([lookup(db, body), lookup(db, body)]);
  assert.equal(results[0].length, 2);
  await lookup(db, body);
  assert.equal(calls, 1);
});
test('OSM outages do not invoke Google and release the shared upstream lock', async () => {
  const db = database(); let calls = 0;
  const lookup = createOsmProvider({fetchImpl: async url => {
    assert.match(url, /overpass/); calls++; return {ok: false};
  }});
  await assert.rejects(lookup(db, {action: 'search', query: 'Da Nang'}), /temporarily unavailable/);
  assert.equal(calls, 1);
  assert.equal(db.values.get('placeUsage/osm-upstream').busyUntil, 0);
});
test('Google disabled by default; explicit opt-in is capped and never requests photos/ratings', async () => {
  const db = database(); let calls = 0;
  const options = {apiKey: 'test', enabled: true, fetchImpl: async (url, request) => {
    calls++; assert.match(url, /searchText$/);
    assert.doesNotMatch(request.headers['X-Goog-FieldMask'], /photos|rating|price/);
    return {ok: true, json: async () => ({places: []})};
  }};
  const body = {query: 'Exact Hotel Name', userRequested: true};
  await assert.rejects(googlePlaceFallback(db, 'user', body), /disabled/);
  await assert.rejects(googlePlaceFallback(db, 'user', {...body, userRequested: false}, options), /explicit/);
  await googlePlaceFallback(db, 'user', body, options);
  await googlePlaceFallback(db, 'user', body, options);
  await assert.rejects(googlePlaceFallback(db, 'user', body, options), /allowance/);
  assert.equal(calls, 2);
});

test('photo exhaustion does not block search, routes or discovery; old shared quota is isolated', async () => {
 const db=database();
 for(let i=0;i<100;i++) { await consumePlaceQuota(db,'user'); await consumePlaceQuota(db,'user','photo'); }
 await assert.rejects(consumePlaceQuota(db,'user','photo'),error=>error.status===429 && /Photo lookup/.test(error.message));
 for(const feature of ['suggest','route','discovery']) await assert.doesNotReject(consumePlaceQuota(db,'user',feature));
 for(let i=1;i<100;i++) await consumePlaceQuota(db,'user','suggest');
 await assert.rejects(consumePlaceQuota(db,'user','suggest'), /Destination search daily limit/);
 await assert.doesNotReject(consumePlaceQuota(db,'another-user','suggest'));
});
