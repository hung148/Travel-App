import test from 'node:test';
import assert from 'node:assert/strict';
import {findPlacePhoto, commonsPhoto} from '../place-photos.js';
const place = {name: 'City Museum', latitude: 16, longitude: 108};
const page = {title: 'File:City Museum.jpg', imageinfo: [{mime: 'image/jpeg',
  thumburl: 'https://upload.wikimedia.org/photo.jpg', descriptionurl: 'https://commons.wikimedia.org/wiki/File:City_Museum.jpg',
  extmetadata: {Artist: {value: 'Photographer'}, LicenseShortName: {value: 'CC BY-SA 4.0'},
    LicenseUrl: {value: 'https://creativecommons.org/licenses/by-sa/4.0/'},
    GPSLatitude: {value: '16'}, GPSLongitude: {value: '108'}}}]};
test('Commons requires name, location, image type and complete licence credit', () => {
  assert.equal(commonsPhoto(page, place).author, 'Photographer');
  assert.equal(commonsPhoto(page, {...place, latitude: 40}), null);
  assert.equal(commonsPhoto(page, {...place, name: 'Another Museum'}), null);
  const bad = structuredClone(page); delete bad.imageinfo[0].extmetadata.Artist;
  assert.equal(commonsPhoto(bad, place), null);
});
test('useful Commons photo prevents Mapillary request', async () => {
  let calls = 0;
  const photo = await findPlacePhoto(place, {mapillaryToken: 'test\r\n', fetchImpl: async url => {
    calls++; assert.equal(url.hostname, 'commons.wikimedia.org');
    return {ok: true, json: async () => ({query: {pages: {1: page}}})};
  }});
  assert.equal(calls, 1); assert.equal(photo.source, 'Wikimedia Commons');
});
test('Mapillary follows empty Commons and carries street-view label and credit', async () => {
  const calls = [];
  const photo = await findPlacePhoto(place, {mapillaryToken: 'test\r\n', fetchImpl: async (url, options) => {
    calls.push(url.hostname);
    if (calls.length === 1) return {ok: true, json: async () => ({})};
    assert.equal(options.headers.Authorization, 'OAuth test');
    return {ok: true, json: async () => ({data: [{id: '123', creator_username: 'tester',
      geometry: {coordinates: [108,16]}, thumb_1024_url: 'https://example.test/image.jpg'}]})};
  }});
  assert.deepEqual(calls, ['commons.wikimedia.org','graph.mapillary.com']);
  assert.equal(photo.nearby, true); assert.equal(photo.license, 'CC BY-SA 4.0');
});
test('provider errors are retryable, not cached as missing imagery', async () => {
  let calls = 0;
  await assert.rejects(findPlacePhoto(place, {fetchImpl: async () => {calls++; return {ok:false};}}), error => error.status === 503);
  assert.equal(calls, 1);
});

test('Commons GeoData coordinates work without GPS in image metadata', () => {
 const geo = structuredClone(page);
 delete geo.imageinfo[0].extmetadata.GPSLatitude;
 delete geo.imageinfo[0].extmetadata.GPSLongitude;
 geo.coordinates = [{lat:16,lon:108}];
 assert.equal(commonsPhoto(geo,place).source,'Wikimedia Commons');
 geo.coordinates = [{lat:40,lon:108}];
 assert.equal(commonsPhoto(geo,place),null);
});
test('a successful empty Commons search returns a true no-match', async () => {
 assert.equal(await findPlacePhoto(place,{fetchImpl:async()=>({ok:true,json:async()=>({query:{pages:{}}})})}),null);
});

test('gallery returns at most five distinct credited Commons photos without Mapillary', async () => {
 const {findPlacePhotos} = await import('../place-photos.js');
 const pages = Object.fromEntries(Array.from({length:8},(_,i)=> {
  const copy = structuredClone(page); copy.imageinfo[0].descriptionurl += `?image=${i}`;
  return [i,copy];
 }));
 let calls=0;
 const photos=await findPlacePhotos(place,{mapillaryToken:'test',fetchImpl:async()=> {
  calls++; return {ok:true,json:async()=>({query:{pages}})};
 }});
 assert.equal(photos.length,5); assert.equal(calls,1);
 assert.ok(photos.every(p=>p.author && p.licenseUrl));
});

test('Commons searches files spatially and includes image metadata in one call', async () => {
 await findPlacePhoto(place,{fetchImpl:async url=> {
  assert.equal(url.searchParams.get('generator'),'geosearch');
  assert.equal(url.searchParams.get('ggscoord'),'16|108');
  assert.equal(url.searchParams.get('ggsnamespace'),'6');
  assert.equal(url.searchParams.get('prop'),'imageinfo|coordinates');
  return {ok:true,json:async()=>({query:{pages:{}}})};
 }});
});
