// Administrator-only, offline ingestion. Never exposed as an app HTTP endpoint.
import {readFile, stat} from 'node:fs/promises';
import {resolve, dirname} from 'node:path';
import {randomUUID} from 'node:crypto';
import {initializeApp, applicationDefault} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {validatePhotoManifest, downloadApprovedImage, imageType} from '../photo-import.js';

const [manifestPath, ...args] = process.argv.slice(2);
const publish = args.includes('--publish');
const projectId = args.find(v => v.startsWith('--project='))?.slice(10);
const bucketName = args.find(v => v.startsWith('--bucket='))?.slice(9);
if (!manifestPath) throw new Error('Usage: node tools/import-place-photos.js manifest.json [--publish --project=ID --bucket=BUCKET]');
const manifest = validatePhotoManifest(JSON.parse(await readFile(manifestPath,'utf8')));
// Validate local files even during dry run; no network downloads or remote writes.
const localBytes = new Map();
for (const photo of manifest.photos.filter(p => p.kind === 'owner')) {
  const path = resolve(dirname(resolve(manifestPath)), photo.localFile);
  if ((await stat(path)).size > 10 * 1024 * 1024) throw new Error('Image exceeds 10 MB.');
  const bytes = await readFile(path); imageType(bytes); localBytes.set(photo, bytes);
}
if (!publish) {
  console.log(`Validated ${manifest.photos.length} photo records for ${manifest.placeId}. No downloads or writes. Publishing replaces this place's approved photo list.`);
} else {
  if (!projectId || !bucketName) throw new Error('Publishing requires explicit --project and --bucket.');
  initializeApp({credential:applicationDefault(), projectId, storageBucket:bucketName});
  const bucket = getStorage().bucket();
  const uploaded = []; const photos = [];
  try {
    for (const photo of manifest.photos) {
      const bytes = photo.kind === 'owner' ? localBytes.get(photo) : await downloadApprovedImage(photo);
      const id = randomUUID();
      const path = `approved-place-photos/${manifest.placeId}/${id}`;
      const file = bucket.file(path); uploaded.push(file);
      await file.save(bytes, {resumable:false, metadata:{contentType:imageType(bytes),
        cacheControl:'private,max-age=300', metadata:{firebaseStorageDownloadTokens:id}}});
      const {localFile,remoteImageUrl,allowedImageHosts,...metadata} = photo;
      photos.push({...metadata, storagePath:path,
        url:`https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucketName)}/o/${encodeURIComponent(path)}?alt=media&token=${id}`});
    }
    await getFirestore().collection('approvedPlacePhotos').doc(manifest.placeId)
      .set({placeId:manifest.placeId, photos, updatedAt:Date.now()});
    console.log(`Published ${photos.length} photos for ${manifest.placeId}. Restart the app to clear its photo cache.`);
  } catch (error) {
    await Promise.allSettled(uploaded.map(file => file.delete({ignoreNotFound:true})));
    throw error;
  }
}
