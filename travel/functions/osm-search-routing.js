import {HttpError} from './endpoint-security.js';
export async function photonSearch(query, {fetchImpl = fetch, endpoint = 'https://photon.komoot.io/api/'} = {}) {
  if (typeof query !== 'string' || query.trim().length < 2 || query.length > 100) throw new HttpError(400, 'Enter a destination name.');
  const url = new URL(endpoint);
  url.search = new URLSearchParams({q: query.trim(), limit: '6', lang: 'en', layer: 'city'});
  const response = await fetchImpl(url, {headers: {'User-Agent': 'NghienTravel/1.0 (destination search)'}, signal: AbortSignal.timeout(7000)});
  if (!response.ok) throw new HttpError(503, 'Destination search is busy. Try again shortly.');
  const data = await response.json();
  return (data.features ?? []).flatMap(feature => {
    const p = feature.properties ?? {}; const c = feature.geometry?.coordinates;
    const type = {N:'node',W:'way',R:'relation'}[p.osm_type];
    if (!type || !Number.isSafeInteger(p.osm_id) || !p.name || !Array.isArray(c) ||
        !Number.isFinite(c[0]) || !Number.isFinite(c[1])) return [];
    return [{id:`osm:${type}:${p.osm_id}`, name:p.name,
      address: [p.state,p.country].filter(Boolean).join(', '), latitude:c[1], longitude:c[0], types:['locality'], source:'openstreetmap'}];
  });
}

export async function osmRoute(body, {apiKey, fetchImpl = fetch} = {}) {
  apiKey = typeof apiKey === 'string' ? apiKey.trim() : '';
  if (!apiKey) throw new HttpError(503, 'Routing is not configured yet.');
  const coordinates = body.coordinates;
  if (!['foot-walking','driving-car'].includes(body.profile) || !Array.isArray(coordinates) ||
      coordinates.length < 2 || coordinates.length > 25 || coordinates.some(c => !Array.isArray(c) || c.length !== 2 ||
        !Number.isFinite(c[0]) || !Number.isFinite(c[1]) || Math.abs(c[0])>180 || Math.abs(c[1])>90)) {
    throw new HttpError(400, 'Invalid route.');
  }
  let response;
  try {
    response = await fetchImpl(`https://api.openrouteservice.org/v2/directions/${body.profile}/geojson`, {
    method:'POST', headers:{Authorization:apiKey,'Content-Type':'application/json'},
    body:JSON.stringify({coordinates, instructions:false}), signal:AbortSignal.timeout(15000)});
  } catch (error) {
    throw new HttpError(503, error.name === 'TimeoutError' || error.name === 'AbortError'
      ? 'Routing timed out. Please retry.' : 'Could not connect to the routing provider. Please retry.');
  }
  if (response.status === 401 || response.status === 403) throw new HttpError(503, 'The routing provider rejected the API key. Check the saved openrouteservice key.');
  if (response.status === 429) throw new HttpError(503, 'The routing provider request limit was reached. Try again later.');
  if (!response.ok) throw new HttpError(503, 'Route unavailable or daily allowance reached.');
  const data = await response.json(); const feature = data.features?.[0];
  const summary = feature?.properties?.summary;
  if (!Array.isArray(feature?.geometry?.coordinates) || !Number.isFinite(summary?.distance) || !Number.isFinite(summary?.duration)) {
    throw new HttpError(503, 'No route found.');
  }
  return {coordinates:feature.geometry.coordinates, distanceMeters:summary.distance,
    durationSeconds:summary.duration, attribution:'openrouteservice · © OpenStreetMap contributors'};
}
