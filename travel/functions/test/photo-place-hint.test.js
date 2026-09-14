import test from 'node:test';
import assert from 'node:assert/strict';
import {photoPlaceHint} from '../photo-place-hint.js';
test('photo hints validate coordinates and discard trusted-image claims',()=> {
 assert.equal(photoPlaceHint({name:'Museum',latitude:200,longitude:108},'osm:node:1'),null);
 assert.deepEqual(photoPlaceHint({name:'Museum',latitude:16,longitude:108,commonsFile:'File:Wrong.jpg',
   wikidata:'Q999',wikipedia:'en:Unrelated place'},'osm:node:1'),
 {id:'osm:node:1',name:'Museum',latitude:16,longitude:108});
});
