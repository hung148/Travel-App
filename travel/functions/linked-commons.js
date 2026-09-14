// Only call with server-resolved OSM metadata, never client-supplied Wikipedia links.
export async function linkedCommonsFiles(place, json) {
  const files = [];
  if (typeof place.commonsFile === 'string' && /^File:[^|\n]{1,250}$/.test(place.commonsFile)) files.push(place.commonsFile);
  if (files.length) return files;
  let id = /^Q[1-9]\d{0,15}$/.test(place.wikidata ?? '') ? place.wikidata : null;
  if (!id && typeof place.wikipedia === 'string') {
    const match = /^([a-z]{2,3}(?:-[a-z]{2,8}){0,2}):([^|\n]{1,250})$/.exec(place.wikipedia);
    if (match) {
      const url = new URL(`https://${match[1]}.wikipedia.org/w/api.php`);
      url.search = new URLSearchParams({action:'query', format:'json', titles:match[2],
        redirects:'1', prop:'pageprops', ppprop:'wikibase_item|disambiguation'});
      const pages = Object.values((await json(url)).query?.pages ?? {});
      const page = pages.length === 1 ? pages[0] : null;
      if (page && !('missing' in page) && !('disambiguation' in (page.pageprops ?? {})) &&
          /^Q[1-9]\d{0,15}$/.test(page.pageprops?.wikibase_item ?? '')) id = page.pageprops.wikibase_item;
    }
  }
  if (id) {
    const url = new URL('https://www.wikidata.org/w/api.php');
    url.search = new URLSearchParams({action:'wbgetentities', format:'json', ids:id, props:'claims'});
    const entity = (await json(url)).entities?.[id];
    for (const claim of entity?.claims?.P18 ?? []) {
      const value = claim.mainsnak?.datavalue?.value;
      if (claim.rank !== 'deprecated' && claim.mainsnak?.snaktype === 'value' &&
          typeof value === 'string' && /^[^|\n]{1,250}$/.test(value)) files.push(`File:${value}`);
    }
  }
  return [...new Set(files)].slice(0, 5);
}
