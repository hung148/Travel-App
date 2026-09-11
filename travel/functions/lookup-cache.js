// Route geometry contains arrays of coordinate arrays, which Firestore cannot store.
export function readLookupCache(cached) {
  if (!cached || cached.expires <= Date.now()) return null;
  try { return cached.resultJson ? JSON.parse(cached.resultJson) : cached.result; }
  catch { return null; }
}
export async function writeLookupCache(ref, result) {
  const resultJson = JSON.stringify(result);
  // Leave room under Firestore's document limit for field names and metadata.
  if (Buffer.byteLength(resultJson, 'utf8') > 800000) return;
  try { await ref.set({resultJson, expires: Date.now() + 3600000}); }
  catch { console.warn('Lookup cache write failed; returning provider result.'); }
}
