# OSM rollout handoff — 2026-09-11

## Current status
Development search, routing and a live photo have been confirmed by the owner.
Latest automatic thumbnails and up-to-five-photo gallery are implemented but still need
live verification after deployment and Flutter restart. Production rollout is pending.

## Behavior
- Photon suggestions after 350 ms typing pause; cached, with stale-response protection.
- Bounded Overpass discovery, stable OSM IDs and honest missing ratings/prices.
- openrouteservice walking/driving; no automatic Google routing fallback.
- Commons first, Mapillary only if no useful Commons image, otherwise placeholder.
- Photos load automatically through a client queue and bounded cache. Gallery contains up
  to five suitable images, with source/author/license links and nearby-street-view labels.
- Existing Google photo URLs blocked. Google fallback remains disabled.

## Development configuration
Ignored file functions/.env.travel-plan-5f810 contains:
```
OSM_ROUTING_ENABLED=true
MAPILLARY_ENABLED=true
```
Secrets OPENROUTESERVICE_API_KEY and MAPILLARY_ACCESS_TOKEN are stored in Firebase
Secret Manager, explicitly bound to searchOsmPlaces, and trimmed before use.
Do not put secret values in Git. A teammate must recreate the environment file locally.

```powershell
npx.cmd firebase-tools deploy --only functions:searchOsmPlaces --project travel-plan-5f810
flutter run -d chrome --dart-define=ENV=dev
```
If Flutter already runs, use uppercase R after updating client code.

## Production gates
Select permitted Overpass, Photon and map-tile hosting with budgets first. Public demo
services are not unlimited production infrastructure. Production discovery is blocked
until OSM_OVERPASS_URL is configured; selecting a public endpoint does not resolve policy.
Review the Photon production path separately. Configure environment and both explicit
secret bindings in production before deploying this function there. No production OSM
rollout or hosting purchase has been completed.

## Limits / remaining checks
Overpass cache misses: 200/day shared, one upstream lease. Each user: 100 lookups/day
shared across features. Suggestion/route/photo upstream budgets are also bounded.
Automatic gallery loading needs load testing against these limits; errors remain retryable.
Firestore caches have expiry checks but still need physical TTL cleanup. Routes are cached
as JSON to avoid Firestore nested-array rejection. Functions/Firestore/bandwidth may cost money.
Google fallback needs its own policy, configuration and secret-binding review before use.
See todo.txt for the prioritized remaining work and latest verification record.
