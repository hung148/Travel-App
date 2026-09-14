import {approvedPhotos} from './approved-photos.js';

export function validatePhotoManifest(manifest, now = Date.now()) {
  if (!/^osm:(node|way|relation):[1-9]\d{0,15}$/.test(manifest?.placeId ?? '') ||
      !Array.isArray(manifest.photos) || !manifest.photos.length || manifest.photos.length > 10) {
    throw new Error('Provide an exact OSM placeId and 1–10 photos.');
  }
  for (const photo of manifest.photos) {
    if (!['website','owner'].includes(photo.kind) || photo.status !== 'approved' ||
        photo.permission?.allowsStorage !== true || photo.permission?.placeVerified !== true) {
      throw new Error('Each photo requires storage/display permission and a verified place match.');
    }
    // Temporary URL checks the public metadata before the upload URL exists.
    if (!approvedPhotos({placeId:manifest.placeId, photos:[{...photo,url:'https://example.org/image.jpg'}]},
      manifest.placeId, photo.kind, now).length) throw new Error('Missing credit, permission reference, HTTPS links or future expiry.');
    if (photo.kind === 'website') {
      if (photo.permission?.allowsAutomatedDownload !== true || !Array.isArray(photo.allowedImageHosts) ||
          !photo.allowedImageHosts.length) throw new Error('Website import requires automated-download permission and exact image hosts.');
      const url = new URL(photo.remoteImageUrl);
      if (url.protocol !== 'https:' || url.username || url.password || url.port ||
          !photo.allowedImageHosts.includes(url.hostname) ||
          !/^[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}$/i.test(url.hostname) ||
          /\.(local|internal|localhost)$/i.test(url.hostname)) throw new Error('Image URL must use an approved public HTTPS host.');
    } else if (typeof photo.localFile !== 'string' || !photo.localFile.trim() ||
        photo.permission?.ownerAttestsRights !== true) throw new Error('Owner uploads require a file and rights attestation.');
  }
  return manifest;
}

export function imageType(bytes) {
  if (bytes.length > 10 * 1024 * 1024 || bytes.length < 12) throw new Error('Images must be at most 10 MB.');
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) return 'image/png';
  if (bytes.toString('ascii',0,4) === 'RIFF' && bytes.toString('ascii',8,12) === 'WEBP') return 'image/webp';
  throw new Error('Only JPEG, PNG and WebP files are accepted.');
}

export async function downloadApprovedImage(photo, fetchImpl = fetch) {
  const response = await fetchImpl(photo.remoteImageUrl, {redirect:'error',
    signal:AbortSignal.timeout(15000), headers:{'User-Agent':'NghienTravel-ApprovedPhotoImport/1.0'}});
  if (!response.ok || !/^image\/(jpeg|png|webp)(?:;|$)/i.test(response.headers.get('content-type') ?? '')) {
    throw new Error('Approved URL did not return a supported image.');
  }
  const chunks = []; let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > 10 * 1024 * 1024) throw new Error('Image exceeds 10 MB.');
    chunks.push(chunk);
  }
  const bytes = Buffer.concat(chunks);
  imageType(bytes);
  return bytes;
}
