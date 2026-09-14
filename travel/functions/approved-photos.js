const https = value => {try {const u = new URL(value); return u.protocol === 'https:' && !u.username && !u.password;} catch {return false;}};
// Written only by the admin import tool; clients cannot approve their own images.
export function approvedPhotos(record, placeId, kind, now = Date.now()) {
  if (!record || record.placeId !== placeId || !Array.isArray(record.photos)) return [];
  return record.photos.filter(p => p.kind === kind && p.status === 'approved' &&
    p.permission?.reference && p.permission?.allowsAppDisplay === true &&
    Number.isFinite(p.permission?.expiresAt) && p.permission.expiresAt > now &&
    ['url','sourceUrl','authorUrl','licenseUrl'].every(key => https(p[key])) &&
    ['author','title','license','source'].every(key => typeof p[key] === 'string' && p[key].trim()))
    .slice(0, 5).map(({url,sourceUrl,authorUrl,licenseUrl,author,title,license,source,permission}) =>
      ({url,sourceUrl,authorUrl,licenseUrl,author,title,license,source,nearby:false,expiresAt:permission.expiresAt}));
}

export function approvedFallback(record, placeId) {
  for (const kind of ['website','owner']) {
    const photos = approvedPhotos(record, placeId, kind);
    if (photos.length) return photos;
  }
  return [];
}
