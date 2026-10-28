import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

// Run once with "seed", export/restart the emulators, then run with "verify".
// Uses only synthetic records and refuses nonlocal Admin SDK endpoints.
for (const variable of ['FIREBASE_AUTH_EMULATOR_HOST', 'FIRESTORE_EMULATOR_HOST']) {
  assert.match(process.env[variable] || '', /^(127\.0\.0\.1|localhost):\d+$/);
}
const require = createRequire(new URL('../package.json', import.meta.url));
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const project = process.env.GCLOUD_PROJECT || 'doitnow-c26f9';
initializeApp({ projectId: project });
const db = getFirestore();
const auth = getAuth();
const uid = 'ubac-persistence-owner';
const email = 'ubac-persistence@example.test';
const password = 'Synthetic-emulator-only-123!';
const listPath = `collaborativeLists/${uid}`;
const taskPath = `${listPath}/tasks/persisted-task`;
const createdAt = Timestamp.fromMillis(1767225600000);

if (process.argv[2] === 'seed') {
  await auth.createUser({ uid, email, password, emailVerified: true });
  await db.doc(listPath).set({ ownerId: uid, name: 'Persisted group', memberIds: [uid], createdAt, updatedAt: createdAt });
  await db.doc(taskPath).set({ ownerId: uid, title: 'Persisted task', details: '', createdAt,
    dueDate: null, dueTime: null, priority: 'medium', category: 'school', isDone: false });
  console.log('Seeded one synthetic Auth account, list and shared task.');
} else {
  assert.equal(process.argv[2], 'verify');
  const account = await auth.getUser(uid);
  assert.equal(account.email, email);
  assert.equal(account.emailVerified, true);
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-key`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  assert.equal(response.status, 200);
  const token = (await response.json()).idToken;
  for (const path of [listPath, taskPath]) {
    const restored = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${project}/databases/(default)/documents/${path}`, {
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(restored.status, 200);
    assert.equal((await restored.json()).fields.ownerId.stringValue, uid);
  }
  assert.deepEqual((await db.doc(listPath).get()).data().memberIds, [uid]);
  assert.equal((await db.doc(taskPath).get()).data().createdAt.toMillis(), createdAt.toMillis());
  console.log('PASS: Auth login, list membership and shared task survived export/import restart.');
}
await db.terminate();
