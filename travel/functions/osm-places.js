import { createHash } from 'node:crypto';
import { HttpError } from './endpoint-security.js';

// No arbitrary Overpass QL, URLs or tag names are accepted from clients.
const header = '[out:json][timeout:20][maxsize:16777216];';
const hash = value => createHash('sha256').update(value).digest('hex');
const validCoordinate = (n, limit) => typeof n === 'number' && Number.isFinite(n) && Math.abs(n) <= limit;
const quote = value => JSON.stringify(value);
function namePattern(name) {
  const variants = {a: 'aàáảãạăằắẳẵặâầấẩẫậ', e: 'eèéẻẽẹêềếểễệ',
    i: 'iìíỉĩị', o: 'oòóỏõọôồốổỗộơờớởỡợ', u: 'uùúủũụưừứửữự',
    y: 'yỳýỷỹỵ', d: 'dđ'};
  return [...name.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replaceAll('đ', 'd')]
    .map(char => variants[char] ? `[${variants[char]}]` : /\s/.test(char) ? '[[:space:]]*'
      : char.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('');
}

export function osmRequest(body) {
  if (body?.action === 'area') {
    if (body.scope !== undefined && body.scope !== 'activities') throw new HttpError(400, 'Unsupported area scope.');
    if (!validCoordinate(body.latitude, 90) || !validCoordinate(body.longitude, 180) ||
        !Number.isInteger(body.radius) || body.radius < 100 || body.radius > 20000) {
      throw new HttpError(400, 'Choose an area between 100 metres and 20 kilometres.');
    }
    const around = `(around:${body.radius},${body.latitude.toFixed(4)},${body.longitude.toFixed(4)})`;
    // Independent output limits keep plentiful food/hotel nodes from consuming
    // the entire result cap before park, museum and landmark ways are returned.
    const groups = [
      {limit: 220, tags: ['[tourism~"^(attraction|museum|viewpoint|gallery|zoo|aquarium|theme_park)$"]',
        '[historic~"^(monument|memorial|castle|ruins|archaeological_site|fort)$"]',
        '[leisure~"^(park|garden|nature_reserve)$"]', '[natural=beach]']},
      {limit: 100, tags: ['[amenity=restaurant]']},
      {limit: 30, tags: ['[amenity=cafe]']},
      {limit: 20, tags: ['[amenity~"^(fast_food|bar|pub)$"]', '[shop=bakery]']},
      {limit: 80, tags: ['[tourism~"^(hotel|hostel|guest_house|motel)$"]']},
      {limit: 50, tags: ['[amenity=marketplace]', '[shop~"^(mall|department_store)$"]']},
    ];
    // Filter names on the already-local result set. A regex over tag keys in
    // each global selector can be much more expensive than exact-key checks.
    const selectedGroups = body.scope === 'activities' ? groups.slice(0, 1) : groups;
    return {query: header + selectedGroups.map(({limit, tags}) =>
      `(${tags.map(tag => `nwr${around}${tag};`).join('')})->.local;` +
      `(nwr.local[name];nwr.local["name:en"];nwr.local["name:vi"];);out center tags ${limit};`).join('')};
  }
  if (body?.action === 'search') {
    const name = typeof body.query === 'string' ? body.query.trim().split(',')[0].trim() : '';
    if (name.length < 2 || name.length > 100) throw new HttpError(400, 'Enter a city or town name.');
    const escaped = namePattern(name);
    const pattern = quote(`^${escaped}$`);
    // Exact settlement names only: no worldwide prefix scan or per-keystroke lookup.
    return {query: `${header}(${['name', 'name:en', 'name:vi'].map(key =>
      `node[place~"^(city|town|village|island)$"][${quote(key)}~${pattern},i];`).join('')});out body 10;`};
  }
  if (body?.action === 'details' && /^osm:(node|way|relation):[1-9]\d{0,15}$/.test(body.id ?? '')) {
    const [, type, id] = body.id.split(':');
    return {query: `${header}${type}(${id});out center tags 1;`};
  }
  throw new HttpError(400, 'Unsupported place lookup.');
}

export function normalizeElements(elements) {
  const places = new Map();
  for (const item of Array.isArray(elements) ? elements : []) {
    const tags = item.tags ?? {};
    const name = tags.name ?? tags['name:en'];
    const latitude = item.lat ?? item.center?.lat;
    const longitude = item.lon ?? item.center?.lon;
    if (typeof name !== 'string' || !name.trim() || !validCoordinate(latitude, 90) ||
        !validCoordinate(longitude, 180) || !['node', 'way', 'relation'].includes(item.type) || !Number.isSafeInteger(item.id)) continue;
    const types = [];
    const mappings = {attraction: 'tourist_attraction', museum: 'museum', viewpoint: 'tourist_attraction',
      gallery: 'art_gallery', zoo: 'zoo', aquarium: 'aquarium', theme_park: 'amusement_park',
      monument: 'historical_landmark', memorial: 'historical_landmark', castle: 'historical_landmark',
      ruins: 'historical_landmark', archaeological_site: 'historical_landmark', fort: 'historical_landmark',
      garden: 'garden', nature_reserve: 'national_park',
      hotel: 'hotel', hostel: 'hostel', guest_house: 'guest_house', motel: 'motel',
      restaurant: 'restaurant', cafe: 'cafe', fast_food: 'meal_takeaway', bar: 'bar', pub: 'bar',
      marketplace: 'market', park: 'park', beach: 'beach', mall: 'shopping_mall',
      department_store: 'department_store', bakery: 'bakery'};
    for (const tag of ['tourism', 'historic', 'amenity', 'leisure', 'natural', 'shop']) {
      if (mappings[tags[tag]]) types.push(mappings[tags[tag]]);
    }
    if (tags.place) types.push('locality');
    const id = `osm:${item.type}:${item.id}`;
    places.set(id, {id, name: name.slice(0, 200), latitude, longitude,
      address: [tags['addr:housenumber'], tags['addr:street'], tags['addr:city'], tags['addr:country']]
        .filter(value => typeof value === 'string').join(', ').slice(0, 400),
      types: [...new Set(types)], source: 'openstreetmap'});
    if (typeof tags.wikimedia_commons === 'string' && tags.wikimedia_commons.startsWith('File:')) {
      places.get(id).commonsFile = tags.wikimedia_commons.slice(0, 250);
    }
    if (/^Q[1-9]\d{0,15}$/.test(tags.wikidata ?? '')) places.get(id).wikidata = tags.wikidata;
    if (typeof tags.wikipedia === 'string' && /^[a-z]{2,3}(?:-[a-z]{2,8}){0,2}:[^|\n]{1,250}$/.test(tags.wikipedia)) {
      places.get(id).wikipedia = tags.wikipedia;
    }
  }
  return [...places.values()];
}

export function createOsmProvider({fetchImpl = fetch, endpoint = 'https://overpass-api.de/api/interpreter'} = {}) {
  const active = new Map();
  return async function lookup(database, body) {
    const {query} = osmRequest(body);
    const id = hash(query);
    if (active.has(id)) return active.get(id);
    const request = (async () => {
      const ref = database.collection('osmPlaceCache').doc(id);
      const cached = (await ref.get()).data();
      if (cached?.expires > Date.now()) return cached.places;
      // Shared across instances: cap all cache misses and serialize upstream work.
      const quota = database.collection('placeUsage').doc('osm-upstream');
      await database.runTransaction(async tx => {
        const now = Date.now();
        const prior = (await tx.get(quota)).data() ?? {};
        const day = Math.floor(now / 86400000);
        const count = prior.day === day ? prior.count ?? 0 : 0;
        if ((prior.retryAfterUntil ?? 0) > now) throw new HttpError(503, 'OpenStreetMap search is temporarily unavailable.');
        if (count >= 200 || (prior.busyUntil ?? 0) > now) throw new HttpError(429, 'Place search is busy. Try again shortly.');
        tx.set(quota, {day, count: count + 1, busyUntil: now + 30000, retryAfterUntil: 0});
      });
      try {
        const response = await fetchImpl(endpoint, {method: 'POST',
          headers: {'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'NghienTravel/1.0 (OSM place lookup)'},
          body: new URLSearchParams({data: query}), signal: AbortSignal.timeout(25000)});
        if (!response.ok) {
          console.warn('OSM upstream HTTP failure', {status:response.status,
            action:body.action, radius:body.action === 'area' ? body.radius : null,
            scope:body.scope ?? 'all'});
          if (response.status === 429 || response.status >= 500) {
            const value = response.headers?.get('retry-after');
            const seconds = value && /^\d+$/.test(value) ? Number(value) :
              value ? (Date.parse(value) - Date.now()) / 1000 : 60;
            const delay = Number.isFinite(seconds) ? Math.min(3600, Math.max(60,seconds)) : 60;
            await quota.update({retryAfterUntil:Date.now()+delay*1000});
          }
          throw new HttpError(503, 'OpenStreetMap search is temporarily unavailable.');
        }
        const data = await response.json();
        if (data.remark) {
          console.warn('OSM incomplete query', {reason: /timed out|timeout/i.test(data.remark) ? 'timeout' :
            /memory|size/i.test(data.remark) ? 'resource_limit' : 'provider_remark',
            action:body.action, radius:body.action === 'area' ? body.radius : undefined});
          throw new HttpError(503, 'Place search could not finish. Try a smaller area.');
        }
        const places = normalizeElements(data.elements);
        if (body.action === 'area') {
          const diningTypes = ['restaurant','cafe','meal_takeaway','bakery','bar','pub'];
          const lodgingTypes = ['hotel','hostel','guest_house','motel'];
          console.info('OSM area discovery', {
            total: places.length,
            activities: places.filter(p => p.types.some(t => !diningTypes.includes(t) &&
              !lodgingTypes.includes(t) && !['shopping_mall','department_store','market','locality'].includes(t))).length,
            dining: places.filter(p => p.types.some(t => diningTypes.includes(t))).length,
            lodging: places.filter(p => p.types.some(t => lodgingTypes.includes(t))).length,
          });
        }
        // Trusted identities let later photos use OSM links without another Overpass call.
        if (places.length && database.batch) {
          const batch = database.batch();
          for (const place of places) batch.set(database.collection('osmPhotoIdentities').doc(place.id),
            {place, expires: Date.now() + 86400000});
          try { await batch.commit(); }
          catch { console.warn('Photo identity cache write failed; place discovery remains available.'); }
        }
        await ref.set({places, expires: Date.now() + 86400000, source: 'openstreetmap'});
        return places;
      } finally {
        await quota.update({busyUntil: 0});
      }
    })();
    active.set(id, request);
    try { return await request; } finally { active.delete(id); }
  };
}

export async function consumePlaceQuota(database, uid, feature = null) {
  const labels = {suggest:'Destination search', route:'Routing', photo:'Photo lookup', discovery:'Place discovery'};
  if (feature !== null && !labels[feature]) throw new Error('Unknown quota feature');
  const ref = database.collection('placeUsage').doc(hash(feature ? `v2:${feature}:${uid}` : uid));
  await database.runTransaction(async tx => {
    const day = Math.floor(Date.now() / 86400000);
    const previous = (await tx.get(ref)).data() ?? {};
    const count = previous.day === day ? previous.count ?? 0 : 0;
    if (count >= 100) throw new HttpError(429, feature ? `${labels[feature]} daily limit reached. Try again after 00:00 UTC.` : 'Daily place lookup limit reached.');
    tx.set(ref, {day, count: count + 1});
  });
}
