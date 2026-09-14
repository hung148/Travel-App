# Place photo sources

Implemented locally, September 13, 2026. Backend deployment and live trip verification are pending.

The first source with usable images supplies up to five photos:

1. Wikimedia Commons: exact OSM `wikimedia_commons` file, or OSM `wikidata` → P18 images,
   or OSM `wikipedia` → exact article's Wikidata entity → P18. No entity is guessed from a name.
   Wikipedia disambiguation pages and deprecated P18 claims are excluded. File-level MIME,
   author, license and credit checks still apply. Strict geographic Commons search follows
   when linked images do not produce a usable result.
2. Approved tourism/venue website photos, imported ahead of time.
3. Owner-supplied files, imported by the administrator with a rights attestation.
4. Mapillary, labelled nearby street imagery rather than a verified venue photo.

This is an administrator upload workflow, not a public traveler/venue-owner upload screen.
Approved photos use the existing gallery and credit links. Imports do not run during schedule
generation. No tourism website has been enabled and no owner files have been supplied yet.

## Trust, caching and limits

Overpass normalization preserves direct entity links (not brand/operator links). Area results
populate `osmPhotoIdentities` with 24-hour server-resolved identities, at most 500 writes per
uncached area. Cache-write failure does not block discovery. Older results can require one
details lookup; if it fails, client hints support only the strict geographic search.
Client-provided Commons/Wikidata/Wikipedia claims are discarded.

`approvedPlacePhotos` and `osmPhotoIdentities` have no client access under the existing default
deny Firestore rules. Only Admin SDK writes can approve images. Never relax these collections
to ordinary authenticated writes. The importer needs Application Default Credentials for the
explicit project and an existing Storage bucket; it does not provision a bucket or change rules.

Photo cache version is v5. Approved-record changes affect its key; permission expiry bounds
server caching. App thumbnails can remain cached for up to 30 minutes, so restart the app after
imports/removal. For urgent takedowns, delete the corresponding Storage objects as well as
removing the approved metadata. Storage download-token URLs are shareable and do not expire
automatically when permission metadata expires. Replaced imports leave old objects for explicit
cleanup after review. Keep original permission records in private operator storage.

Per-user and shared provider budgets still apply. One photo lookup may now call Wikipedia,
Wikidata and Commons sequentially before fallback; each provider request is bounded to five
seconds. Old places needing Overpass details can take longer. Monitor latency and quota use.
Set `WIKIMEDIA_USER_AGENT` to an app identifier containing a real operator contact URL/email
before production; no contact address has been invented in code.

## Import approved website images or owner photos

Run from `travel/functions`. The tool is for trusted, reviewed administrator manifests only.
It fetches exact approved image URLs, with exact allowed hosts, no redirects, no recursive page
crawling and a 10 MB limit. It accepts JPEG/PNG/WebP signatures and rejects SVG/HTML; it does
not decode/re-encode images or strip EXIF. Review files before publishing. Imports run serially.

Create a private manifest using the schema below. Use the exact OSM place ID from the trip and
verify each image depicts that place. Replace every placeholder with real evidence. The
example deliberately lacks approval and will fail validation until completed.

```json
{
  "placeId": "osm:node:REPLACE_WITH_REAL_ID",
  "photos": [{
    "kind": "website",
    "status": "pending",
    "remoteImageUrl": "https://images.example.org/approved-photo.jpg",
    "allowedImageHosts": ["images.example.org"],
    "source": "Venue name",
    "sourceUrl": "https://example.org/exact-place-page",
    "author": "Photographer name",
    "authorUrl": "https://example.org/photographer",
    "title": "Exact place and image description",
    "license": "Used with permission",
    "licenseUrl": "https://example.org/public-reuse-terms",
    "permission": {
      "reference": "Private permission record identifier",
      "allowsAppDisplay": false,
      "allowsStorage": false,
      "allowsAutomatedDownload": false,
      "placeVerified": false,
      "expiresAt": 0
    }
  }]
}
```

`expiresAt` is a future Unix timestamp in milliseconds, chosen from the permission's validity
or an operator review date for perpetual permission. Permissions must cover the actual app use
(including commercial use if applicable), hosting and the gallery's credit presentation.
Do not approve licenses requiring thumbnail credits until that presentation is implemented.

For owner files use `kind: "owner"`, `source: "Owner upload"`, `localFile: "./museum.jpg"`
(relative to the manifest) instead of remoteImageUrl/allowedImageHosts. Add
`permission.ownerAttestsRights: true`. Supply the same public credit/permission links and
storage/display grants. Set `status: "approved"` only after review.

```powershell
node tools/import-place-photos.js path/to/manifest.json
node tools/import-place-photos.js path/to/manifest.json --publish --project=travel-plan-5f810 --bucket=ACTUAL_BUCKET_NAME
```

The first command validates without downloads or writes. The second downloads approved website
files or reads owner files, uploads to Storage, then replaces that place's approved list. Include
both website and owner records in one manifest to retain both fallbacks (maximum ten records).
No publish command has been run as part of this implementation.

## Tourism sources researched

Checked September 13, 2026:

| Source | Finding | Activation |
| --- | --- | --- |
| [Vietnam Tourism image galleries](https://vietnam.travel/vietnam-image-galleries) | Destination galleries are offered for tourism promotion with photographer credits. | Candidate only; detailed terms below restrict use. |
| [Vietnam Tourism industry resources](https://vietnam.travel/things-to-do/vietnam-resources-travel-industry) | Photography rules specify non-commercial use, no modifications and photographer captions. Requests can go to editor@tabvietnam.vn. | Needs permission covering this app's usage and credit placement. No message sent. |
| [Vietnam Tourism general terms](https://www.vietnam.travel/term-conditions) | General site content requires prior written permission; website-wide crawling is not licensed. | Disabled. |
| [Da Nang Fantasticity](https://danangfantasticity.com/en/da-nang-officially-launches-photo-trip-2026-return-to-origins) | Official tourism portal has photography, but the reviewed page does not establish an app reuse license. | Disabled pending a specific grant. |

A permission request should identify the app, intended commercial/non-commercial use, exact
photos, storage/download method, photographer credits and whether thumbnail display is allowed.
Public access to a website is not recorded as permission.

API references: [Wikibase API](https://www.mediawiki.org/wiki/Wikibase/API),
[Wikipedia page properties](https://www.mediawiki.org/wiki/API:Pageprops),
[Commons reuse](https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia/en).
