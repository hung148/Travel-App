import test from 'node:test';
import assert from 'node:assert/strict';
import {photonSearch, osmRoute} from '../osm-search-routing.js';
test('Photon requests bounded city suggestions and preserves OSM identity', async () => {
 const places = await photonSearch('Da Nang', {fetchImpl: async url => {
  assert.equal(url.searchParams.get('layer'),'city');
  assert.equal(url.searchParams.get('limit'),'6');
  return {ok:true,json:async()=>({features:[{properties:{osm_type:'R',osm_id:1891418,name:'Da Nang',country:'Vietnam'},geometry:{coordinates:[108.212,16.068]}}]})};
 }});
 assert.equal(places[0].id,'osm:relation:1891418'); assert.equal(places[0].latitude,16.068);
});
test('routing requires configuration and rejects invalid coordinates before fetching', async () => {
 await assert.rejects(osmRoute({}), /not configured/);
 await assert.rejects(osmRoute({profile:'driving-car',coordinates:[[999,0],[1,2]]},{apiKey:'test'}), /Invalid route/);
});
test('ORS route preserves geometry and metric units without Google', async () => {
 const route = await osmRoute({profile:'foot-walking',coordinates:[[108,16],[108.1,16.1]]},{apiKey:' test\r\n',fetchImpl:async (url,options)=>{
  assert.equal(new URL(url).hostname,'api.openrouteservice.org'); assert.equal(options.headers.Authorization,'test');
  return {ok:true,json:async()=>({features:[{geometry:{coordinates:[[108,16],[108.1,16.1]]},properties:{summary:{distance:1234,duration:890}}}]})};
 }});
 assert.equal(route.distanceMeters,1234);assert.equal(route.durationSeconds,890);
});

test('routing network failures return a safe actionable error', async () => {
 await assert.rejects(osmRoute({profile:'foot-walking',coordinates:[[108,16],[108.1,16.1]]},
  {apiKey:'test',fetchImpl:async()=>{throw new TypeError('fetch failed');}}),
  error=>error.status === 503 && /connect to the routing provider/.test(error.message));
});
