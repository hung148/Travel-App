import test from 'node:test';
import assert from 'node:assert/strict';
import {readLookupCache, writeLookupCache} from '../lookup-cache.js';
test('nested route coordinates are stored as text and round-trip unchanged', async () => {
 const result = {route:{coordinates:[[108,16],[108.2,16.1]],distanceMeters:2000}};
 let saved;
 await writeLookupCache({set:async data=>{assert.equal(typeof data.resultJson,'string');saved=data;}},result);
 assert.deepEqual(readLookupCache(saved),result);
});
test('cache failures do not reject successful provider results', async () => {
 await assert.doesNotReject(writeLookupCache({set:async()=>{throw Error('unavailable');}}, {route:{coordinates:[[1,2],[3,4]]}}));
});
test('expired cache is ignored and previous suggestion format still works',()=>{
 assert.equal(readLookupCache({expires:1,result:{places:[]}}),null);
 assert.deepEqual(readLookupCache({expires:Date.now()+10000,result:{places:[]}}),{places:[]});
});
