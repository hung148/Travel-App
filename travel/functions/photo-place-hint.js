// Client hints avoid repeating Overpass for a place already displayed in the app.
// Never accept direct-file/license claims from the client; photo matching stays strict.
export function photoPlaceHint(value, id) {
  if (!value || typeof value.name !== 'string' || !value.name.trim() || value.name.length > 200 ||
      !Number.isFinite(value.latitude) || Math.abs(value.latitude) > 90 ||
      !Number.isFinite(value.longitude) || Math.abs(value.longitude) > 180) return null;
  return {id, name:value.name.trim(), latitude:value.latitude, longitude:value.longitude};
}
