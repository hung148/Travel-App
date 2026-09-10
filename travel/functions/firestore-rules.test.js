import test from 'node:test';
import fs from 'node:fs/promises';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, deleteDoc, updateDoc, collection, query, where, orderBy, getDocs, writeBatch} from 'firebase/firestore';

test('Firestore owner-filtered reads, verification and independent batch deletion', {skip: !process.env.FIRESTORE_EMULATOR_HOST}, async () => {
  const env = await initializeTestEnvironment({projectId: 'demo-nghientravel', firestore: {rules: await fs.readFile(new URL('../firestore.rules', import.meta.url), 'utf8')}});
  try {
    await env.withSecurityRulesDisabled(async context => {
      const db = context.firestore();
      await setDoc(doc(db, 'trips/t'), {ownerId: 'owner'});
      await setDoc(doc(db, 'trips/other'), {ownerId: 'other'});
      for (let day = 1; day <= 30; day++) await setDoc(doc(db, `itineraries/t_day_${day}`), {ownerId: 'owner', tripId: 't', dayNumber: day});
      await setDoc(doc(db, 'itineraries/legacy'), {tripId: 't'});
    });
    const verified = env.authenticatedContext('owner', {email_verified: true}).firestore();
    const unverified = env.authenticatedContext('owner', {email_verified: false}).firestore();
    const other = env.authenticatedContext('other', {email_verified: true}).firestore();
    await assertFails(getDoc(doc(unverified, 'trips/t')));
    await assertFails(getDoc(doc(other, 'trips/t')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'trips/t')));
    await assertSucceeds(getDoc(doc(verified, 'trips/t')));
    await assertSucceeds(setDoc(doc(unverified, 'users/owner'), {uid: 'owner', email: 'test@example.com'}));
    await assertFails(setDoc(doc(unverified, 'preferences/test'), {ownerId: 'owner'}));
    await assertFails(updateDoc(doc(verified, 'itineraries/t_day_1'), {tripId: 'other'}));
    await assertSucceeds(getDocs(query(collection(verified, 'itineraries'), where('ownerId', '==', 'owner'))));
    await assertSucceeds(getDocs(query(collection(verified, 'itineraries'),
      where('ownerId', '==', 'owner'), where('tripId', '==', 't'), orderBy('dayNumber'))));
    await assertFails(getDocs(query(collection(verified, 'itineraries'), where('tripId', '==', 't'))));
    await assertFails(getDoc(doc(other, 'itineraries/t_day_1')));
    await assertFails(deleteDoc(doc(other, 'itineraries/t_day_1')));
    await assertFails(getDoc(doc(unverified, 'itineraries/t_day_1')));
    await assertFails(getDoc(doc(verified, 'itineraries/legacy')));
    await assertFails(deleteDoc(doc(verified, 'itineraries/legacy')));
    // Reads/deletes no longer depend on the parent trip's continued existence.
    await assertSucceeds(deleteDoc(doc(verified, 'trips/t')));
    const batch = writeBatch(verified);
    for (let day = 1; day <= 30; day++) batch.delete(doc(verified, `itineraries/t_day_${day}`));
    await assertSucceeds(batch.commit());
  } finally { await env.cleanup(); }
});
