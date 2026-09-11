import {HttpError} from './endpoint-security.js';
const text = value => String(value ?? '').replace(/<[^>]*>/g, '').replace(/&[^;]+;/g, ' ').trim();
const https = value => { try { return new URL(value).protocol === 'https:'; } catch { return false; } };
const normalized = value => text(value).normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();

export function commonsPhoto(page, place, directlyLinked = false) {
  const info = page.imageinfo?.[0];
  const meta = info?.extmetadata ?? {};
  const license = text(meta.LicenseShortName?.value);
  const author = text(meta.Artist?.value);
  const licenseUrl = meta.LicenseUrl?.value;
  const title = text(page.title?.replace(/^File:/, ''));
  const match = normalized(title + ' ' + text(meta.ImageDescription?.value));
  const latitude = Number(page.coordinates?.[0]?.lat ?? meta.GPSLatitude?.value);
  const longitude = Number(page.coordinates?.[0]?.lon ?? meta.GPSLongitude?.value);
  if (!info?.mime?.startsWith('image/') || /svg|gif/.test(info.mime) ||
      (!directlyLinked && (!match.includes(normalized(place.name)) || normalized(place.name).length < 5)) ||
      !/^(CC BY(?:-SA)? [234]\.0|CC0(?: 1\.0)?|Public domain)$/i.test(license) ||
      (!directlyLinked && (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      Math.abs(latitude - place.latitude) > 0.003 || Math.abs(longitude - place.longitude) > 0.003)) ||
      !author || !https(licenseUrl) || !https(info.descriptionurl) || !https(info.thumburl)) return null;
  return {url: info.thumburl, source: 'Wikimedia Commons', sourceUrl: info.descriptionurl,
    author, authorUrl: info.descriptionurl, license, licenseUrl, title, nearby: false};
}

export async function findPlacePhotos(place, {fetchImpl = fetch, mapillaryToken = ''} = {}) {
  const failures = [];
  const photos = [];
  async function json(url, headers = {}) {
    const response = await fetchImpl(url, {headers: {'User-Agent': 'NghienTravel/1.0 (place photo lookup)', ...headers},
      signal: AbortSignal.timeout(8000)});
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    if (data.error) throw new Error('Provider API error');
    return data;
  }
  try {
    const url = new URL('https://commons.wikimedia.org/w/api.php');
    url.search = new URLSearchParams({action: 'query', format: 'json',
      ...(place.commonsFile ? {titles:place.commonsFile} : {generator:'geosearch',
      ggscoord: `${place.latitude}|${place.longitude}`, ggsradius:'500',
      ggsnamespace:'6', ggsprimary:'all', ggslimit:'20'}),
      prop: 'imageinfo|coordinates', colimit:'1', iiprop: 'url|extmetadata|mime', iiurlwidth: '800'});
    const data = await json(url);
    for (const page of Object.values(data.query?.pages ?? {})) {
      const photo = commonsPhoto(page, place, Boolean(place.commonsFile));
      if (photo && !photos.some(p => p.sourceUrl === photo.sourceUrl)) photos.push(photo);
      if (photos.length === 5) break;
    }
  } catch (error) {
    console.warn('Photo provider failure', {provider:'commons', reason:/^HTTP \d{3}$/.test(error.message) ? error.message : 'network_or_api_error'});
    failures.push('Wikimedia Commons');
  }
  if (photos.length) return photos;
  mapillaryToken = mapillaryToken.trim();
  if (!mapillaryToken) {
    if (failures.length) throw new HttpError(503, 'Wikimedia Commons is unavailable. Please retry later.');
    return [];
  }
  try {
    const delta = 0.0015;
    const url = new URL('https://graph.mapillary.com/images');
    url.search = new URLSearchParams({bbox: [place.longitude-delta, place.latitude-delta,
      place.longitude+delta, place.latitude+delta].join(','), limit: '5',
      fields: 'id,thumb_1024_url,creator_username,geometry,captured_at'});
    const data = await json(url, {Authorization: `OAuth ${mapillaryToken}`});
    for (const item of data.data ?? []) {
      const author = item.creator_username ?? item.creator?.username;
      const coordinates = item.geometry?.coordinates;
      if (!/^\d+$/.test(item.id ?? '') || typeof author !== 'string' || !https(item.thumb_1024_url) ||
          !Array.isArray(coordinates) || !Number.isFinite(coordinates[0]) || !Number.isFinite(coordinates[1]) || Math.abs(coordinates[0]-place.longitude) > delta ||
          Math.abs(coordinates[1]-place.latitude) > delta) continue;
      if (photos.some(p => p.sourceUrl.includes(`pKey=${item.id}&`))) continue;
      photos.push({url: item.thumb_1024_url, source: 'Mapillary',
        sourceUrl: `https://www.mapillary.com/app/?pKey=${item.id}&focus=photo`,
        author, authorUrl: `https://www.mapillary.com/app/user/${encodeURIComponent(author)}`,
        title: 'Nearby street view', nearby: true, license: 'CC BY-SA 4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/'});
      if (photos.length === 5) break;
    }
  } catch (error) {
    console.warn('Photo provider failure', {provider:'mapillary', reason:/^HTTP \d{3}$/.test(error.message) ? error.message : 'network_or_api_error'});
    failures.push('Mapillary');
  }
  if (photos.length) return photos;
  if (failures.length) throw new HttpError(503, `${failures.join(' and ')} photo lookup failed. Please retry later.`);
  return [];
}

export async function findPlacePhoto(place, options) { return (await findPlacePhotos(place, options))[0] ?? null; }
