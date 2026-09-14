import test from 'node:test';
import assert from 'node:assert/strict';
import {linkedCommonsFiles} from '../linked-commons.js';
import {approvedPhotos} from '../approved-photos.js';
import {findPlacePhotos} from '../place-photos.js';
import {validatePhotoManifest, imageType, downloadApprovedImage} from '../photo-import.js';
import {normalizeElements} from '../osm-places.js';

const place = {id:'osm:node:1',name:'Bảo tàng',latitude:16,longitude:108};
const photo = {kind:'website',status:'approved',url:'https://images.example.org/a.jpg',
  source:'Venue website',sourceUrl:'https://example.org/place',author:'Photographer',
  authorUrl:'https://example.org/author',license:'Used with permission',licenseUrl:'https://example.org/license',
  title:'Museum exterior',permission:{reference:'written-permission-record',allowsAppDisplay:true,
    allowsStorage:true,allowsAutomatedDownload:true,placeVerified:true,expiresAt:Date.now()+86400000},
  allowedImageHosts:['images.example.org'],remoteImageUrl:'https://images.example.org/a.jpg'};
const claim = value => ({rank:'normal',mainsnak:{snaktype:'value',datavalue:{value}}});
const empty = {ok:true,json:async()=>({})};

test('OSM preserves only valid direct entity links, never brand:wikidata', () => {
  const [p] = normalizeElements([{type:'node',id:1,lat:16,lon:108,tags:{name:'Museum',
    wikidata:'Q123',wikipedia:'vi:Bảo tàng', 'brand:wikidata':'Q999'}}]);
  assert.equal(p.wikidata,'Q123'); assert.equal(p.wikipedia,'vi:Bảo tàng');
  const [bad] = normalizeElements([{type:'node',id:1,lat:16,lon:108,tags:{name:'Museum',
    wikidata:'https://evil.test',wikipedia:'en:One|Two','brand:wikidata':'Q999'}}]);
  assert.equal(bad.wikidata,undefined); assert.equal(bad.wikipedia,undefined);
});

test('verified Vietnamese Wikipedia page resolves to Wikidata P18 without name search', async () => {
  const hosts=[];
  const files=await linkedCommonsFiles({...place,wikipedia:'vi:Bảo tàng'},async url=> {
    hosts.push(url.hostname);
    if (hosts.length===1) {
      assert.equal(url.searchParams.get('titles'),'Bảo tàng');
      return {query:{pages:{1:{pageprops:{wikibase_item:'Q123'}}}}};
    }
    assert.equal(url.searchParams.get('ids'),'Q123');
    return {entities:{Q123:{claims:{P18:[claim('Museum.jpg'),claim('Museum.jpg'),
      {...claim('Old.jpg'),rank:'deprecated'}]}}}};
  });
  assert.deepEqual(hosts,['vi.wikipedia.org','www.wikidata.org']);
  assert.deepEqual(files,['File:Museum.jpg']);
});

test('Wikipedia disambiguation and invalid links cannot authorize a photo', async () => {
  assert.deepEqual(await linkedCommonsFiles({...place,wikipedia:'en:Ambiguous'},async()=>
    ({query:{pages:{1:{pageprops:{wikibase_item:'Q123',disambiguation:''}}}}})),[]);
  assert.deepEqual(await linkedCommonsFiles({...place,wikipedia:'https://evil.test'},async()=>
    {throw new Error('must not fetch');}),[]);
});

test('linked Commons image can lack geotags and English name but still needs license', async () => {
  const calls=[];
  const result=await findPlacePhotos({...place,wikidata:'Q123'},{fetchImpl:async url=> {
    calls.push(url.hostname);
    if(url.hostname==='www.wikidata.org') return {ok:true,json:async()=>({entities:{Q123:{claims:{P18:[claim('Different name.jpg')]}}}})};
    assert.equal(url.searchParams.get('titles'),'File:Different name.jpg');
    return {ok:true,json:async()=>({query:{pages:{1:{title:'File:Different name.jpg',imageinfo:[{
      mime:'image/jpeg',thumburl:'https://upload.wikimedia.org/image.jpg',
      descriptionurl:'https://commons.wikimedia.org/wiki/File:Different_name.jpg',extmetadata:{
        Artist:{value:'Photographer'},LicenseShortName:{value:'CC BY-SA 4.0'},
        LicenseUrl:{value:'https://creativecommons.org/licenses/by-sa/4.0/'}}}]}}}})};
  }});
  assert.equal(result[0].source,'Wikimedia Commons');
  assert.deepEqual(calls,['www.wikidata.org','commons.wikimedia.org']);
});

test('approved website precedes owner and Mapillary; owner follows unapproved website', async () => {
  const owner={...photo,kind:'owner',source:'Owner upload'};
  const record={placeId:place.id,photos:[owner,photo]};
  let calls=0;
  const options={approvedRecord:record,mapillaryToken:'token',fetchImpl:async url=> {
    calls++; assert.equal(url.hostname,'commons.wikimedia.org'); return empty;
  }};
  assert.equal((await findPlacePhotos(place,options))[0].source,'Venue website');
  photo.status='pending';
  try {assert.equal((await findPlacePhotos(place,options))[0].source,'Owner upload');}
  finally {photo.status='approved';}
  assert.equal(calls,2);
});

test('Commons failure still permits approved photos; expired/mismatched records fail closed', async () => {
  const record={placeId:place.id,photos:[photo]};
  const photos=await findPlacePhotos(place,{approvedRecord:record,fetchImpl:async()=>({ok:false,status:503})});
  assert.equal(photos[0].source,'Venue website');
  assert.deepEqual(approvedPhotos(record,'osm:node:2','website'),[]);
  assert.deepEqual(approvedPhotos(record,place.id,'website',photo.permission.expiresAt),[]);
  assert.deepEqual(approvedPhotos({...record,photos:[{...photo,permission:{}}]},place.id,'website'),[]);
});

test('import requires explicit permissions, host matching and owner rights', () => {
  assert.doesNotThrow(()=>validatePhotoManifest({placeId:place.id,photos:[photo]}));
  for(const change of [{remoteImageUrl:'https://other.example.org/image.jpg'},
    {remoteImageUrl:'http://images.example.org/a.jpg'}, {permission:{...photo.permission,allowsStorage:false}},
    {kind:'owner',localFile:'image.jpg'}]) {
    assert.throws(()=>validatePhotoManifest({placeId:place.id,photos:[{...photo,...change}]}));
  }
  assert.doesNotThrow(()=>validatePhotoManifest({placeId:place.id,photos:[{...photo,kind:'owner',
    localFile:'image.jpg',permission:{...photo.permission,ownerAttestsRights:true}}]}));
});

test('import rejects HTML/SVG and excessive image sizes; downloads prohibit redirects', async () => {
  assert.throws(()=>imageType(Buffer.from('<svg>not a photo</svg>')));
  assert.throws(()=>imageType(Buffer.alloc(10*1024*1024+1)));
  const png=Buffer.from([137,80,78,71,13,10,26,10,0,0,0,0]);
  assert.equal(imageType(png),'image/png');
  const result=await downloadApprovedImage(photo,async(url,options)=> {
    assert.equal(options.redirect,'error');
    return {ok:true,headers:new Headers({'content-type':'image/png'}),body:(async function*(){yield png;})()};
  });
  assert.deepEqual(result,png);
});
