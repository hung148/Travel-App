// Uses the Firebase CLI's existing session. Never prints or writes tokens/key strings.
// node tools/admin-maintenance.mjs <firebase-tools/lib path> <project> <inspect|backfill|disable-phone|cleanup-dev> [--apply]
import {createRequire} from 'node:module';
import path from 'node:path';
import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {Firestore, FieldPath} from '@google-cloud/firestore';
import {OAuth2Client} from 'google-auth-library';
const [cliPath, project, mode = 'inspect', applyFlag] = process.argv.slice(2);
if (!['travel-plan-5f810', 'travel-app-production-5e372'].includes(project)) throw Error('Specify a known project explicitly');
const apply = applyFlag === '--apply';
const require = createRequire(import.meta.url);
const cliAuth = require(path.join(cliPath, 'auth.js'));
const api = require(path.join(cliPath, 'apiv2.js'));
const {requireAuth} = require(path.join(cliPath, 'requireAuth.js'));
const account = cliAuth.getProjectDefaultAccount(process.cwd());
await requireAuth({project, ...account});
const app = initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await api.getAccessToken(), expires_in: 3000})}});
const oauth = new OAuth2Client();
oauth.refreshHandler = async () => ({access_token: await api.getAccessToken(), expiry_date: Date.now() + 3000000});
const db = new Firestore({projectId: project, authClient: oauth});
const auth = getAuth(app);
const disposableEmails = ['a@gmail.com', 'son@gmail.com', 'xxx@gmail.com'];
async function request(url, method = 'GET', body) {
  const response = await fetch(url, {method, headers: {Authorization: `Bearer ${await api.getAccessToken()}`, 'Content-Type': 'application/json'}, body: body ? JSON.stringify(body) : undefined});
  const result = await response.json();
  if (!response.ok) throw Error(`${response.status}: ${result.error?.message ?? 'Request failed'}`);
  return result;
}
async function backfill() {
  let cursor;
  let checked = 0, missing = 0, orphaned = 0, changed = 0;
  while (true) {
    let query = db.collection('itineraries').orderBy(FieldPath.documentId()).limit(200);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const document of page.docs) {
      checked++;
      const data = document.data();
      if (typeof data.ownerId === 'string' && data.ownerId) continue;
      missing++;
      if (typeof data.tripId !== 'string' || !data.tripId || data.tripId.includes('/')) { orphaned++; continue; }
      const tripRef = db.collection('trips').doc(data.tripId);
      const trip = await tripRef.get();
      if (!trip.exists || !trip.data().ownerId) { orphaned++; continue; }
      if (apply) await db.runTransaction(async tx => {
        const [fresh, parent] = await Promise.all([tx.get(document.ref), tx.get(tripRef)]);
        if (fresh.exists && !fresh.data().ownerId && fresh.data().tripId === tripRef.id && parent.exists && parent.data().ownerId) {
          tx.update(document.ref, {ownerId: parent.data().ownerId}); changed++;
        }
      });
    }
    cursor = page.docs.at(-1);
  }
  console.log(JSON.stringify({project, mode, apply, checked, missing, orphaned, changed}));
  if (orphaned) process.exitCode = 2;
}
async function deleteQuery(query) {
  while (true) {
    const page = await query.limit(400).get();
    if (page.empty) return;
    const batch = db.batch();
    for (const document of page.docs) batch.delete(document.ref);
    await batch.commit();
  }
}
async function cleanup() {
  if (project !== 'travel-plan-5f810') throw Error('Cleanup is restricted to development');
  const {users} = await auth.getUsers(disposableEmails.map(email => ({email})));
  for (const user of users) {
    if (user.emailVerified || !disposableEmails.includes(user.email)) throw Error('Refusing to delete a verified or unexpected account');
    console.log(JSON.stringify({disposableAccount: user.email, apply}));
    if (!apply) continue;
    for (const collection of ['publicDestinationReviews', 'destinationTips', 'preferences']) await deleteQuery(db.collection(collection).where('ownerId', '==', user.uid));
    await deleteQuery(db.collection('feedbacks').where('userId', '==', user.uid));
    const trips = await db.collection('trips').where('ownerId', '==', user.uid).get();
    for (const trip of trips.docs) await deleteQuery(db.collection('itineraries').where('tripId', '==', trip.id));
    await deleteQuery(db.collection('itineraries').where('ownerId', '==', user.uid));
    for (const trip of trips.docs) await trip.ref.delete();
    await db.collection('users').doc(user.uid).delete();
    await auth.deleteUser(user.uid);
  }
  const remaining = await auth.getUsers(disposableEmails.map(email => ({email})));
  console.log(JSON.stringify({remainingDisposableAccounts: remaining.users.length}));
}
try {
  if (mode === 'secret-metadata') {
    const result = await request(`https://secretmanager.googleapis.com/v1/projects/${project}/secrets/OPENAI_API_KEY/versions?pageSize=10`);
    console.log(JSON.stringify({project, versions: (result.versions ?? []).map(version => ({name: version.name, state: version.state, createTime: version.createTime}))}));
  }
  else if (mode === 'backfill') await backfill();
  else if (mode === 'cleanup-dev') await cleanup();
  else if (mode === 'disable-phone') {
    if (project !== 'travel-plan-5f810') throw Error('Phone change is restricted to dev');
    const url = `https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`;
    if (apply) await request(`${url}?updateMask=signIn.phoneNumber.enabled`, 'PATCH', {name: `projects/${project}/config`, signIn: {phoneNumber: {enabled: false}}});
    const config = await request(url);
    console.log(JSON.stringify({project, phoneSignInEnabled: config.signIn?.phoneNumber?.enabled ?? false}));
  } else if (mode === 'inspect') {
    const config = await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`);
    console.log(JSON.stringify({project, phoneSignInEnabled: config.signIn?.phoneNumber?.enabled ?? false}));
    const projectNumber = project === 'travel-plan-5f810' ? '433112330933' : '302713572426';
    const keys = await request(`https://apikeys.googleapis.com/v2/projects/${projectNumber}/locations/global/keys?pageSize=100`);
    console.log(JSON.stringify({keys: keys.keys?.map(key => ({name: key.name, displayName: key.displayName, restrictions: key.restrictions ?? {}})) ?? []}));
    const billing = await request(`https://cloudbilling.googleapis.com/v1/projects/${project}/billingInfo`);
    console.log(JSON.stringify({project, billingEnabled: billing.billingEnabled}));
    if (project === 'travel-plan-5f810') {
      const users = await auth.getUsers(disposableEmails.map(email => ({email})));
      console.log(JSON.stringify({disposableAccounts: users.users.map(user => ({email: user.email, verified: user.emailVerified}))}));
    }
  } else throw Error('Unknown mode');
} catch (error) { console.error(error.message); process.exitCode = 1; }
await db.terminate();
