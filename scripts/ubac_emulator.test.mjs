import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { test } from 'node:test';

// This suite deliberately refuses nonlocal endpoints. No production credentials
// or deployed service is needed; start the Auth and Firestore emulators.
const require = createRequire(new URL('../package.json', import.meta.url));
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const project = process.env.GCLOUD_PROJECT || 'doitnow-c26f9';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
for (const host of [authHost, firestoreHost]) {
  assert.match(host, /^(127\.0\.0\.1|localhost):\d+$/, 'Only loopback emulators are allowed.');
}
process.env.FIREBASE_AUTH_EMULATOR_HOST = authHost;
process.env.FIRESTORE_EMULATOR_HOST = firestoreHost;
initializeApp({ projectId: project });
const adminAuth = getAuth();
const adminDb = getFirestore();
const documentBase = `http://${firestoreHost}/v1/projects/${project}/databases/(default)/documents`;
const password = 'Synthetic-test-password-123!';
let sequence = 0;

async function account(label) {
  const email = `${label}-${Date.now()}-${sequence++}@example.test`;
  const created = await adminAuth.createUser({ email, password, emailVerified: true });
  return { uid: created.uid, email, ...(await signIn(email)) };
}
async function signIn(email) {
  const response = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-key`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const body = await response.json();
  assert.equal(response.status, 200, 'Emulator sign in must succeed.');
  return { token: body.idToken };
}
function value(input) {
  if (input === null) return { nullValue: null };
  if (input instanceof Date) return { timestampValue: input.toISOString() };
  if (Array.isArray(input)) return { arrayValue: { values: input.map(value) } };
  if (typeof input === 'boolean') return { booleanValue: input };
  if (typeof input === 'number') return { integerValue: String(input) };
  return { stringValue: input };
}
function fields(data) {
  return { fields: Object.fromEntries(Object.entries(data).map(([key, entry]) => [key, value(entry)])) };
}
async function rest(method, path, actor, data) {
  const response = await fetch(`${documentBase}${path}`, {
    method,
    headers: { 'content-type': 'application/json', ...(actor ? { authorization: `Bearer ${actor.token}` } : {}) },
    ...(data === undefined ? {} : { body: JSON.stringify(data) }),
  });
  return { status: response.status, body: await response.json() };
}
async function write(path, actor, data) { return rest('PATCH', `/${path}`, actor, fields(data)); }
async function read(path, actor) { return rest('GET', `/${path}`, actor); }
async function denied(result) { assert.equal((await result).status, 403); }
async function ok(result) { assert.equal((await result).status, 200); }
function task(uid, overrides = {}) {
  return { ownerId: uid, title: 'Synthetic task', details: '', createdAt: new Date('2026-01-01T00:00:00Z'),
    dueDate: null, dueTime: null, priority: 'medium', category: 'school', isDone: false, ...overrides };
}
function list(uid, overrides = {}) {
  return { ownerId: uid, name: 'My group', memberIds: [uid], createdAt: new Date(), updatedAt: new Date(), ...overrides };
}
async function updateList(path, actor, overrides = {}) {
  const saved = (await adminDb.doc(path).get()).data();
  return write(path, actor, {
    ...saved,
    createdAt: saved.createdAt.toDate(),
    updatedAt: saved.updatedAt.toDate(),
    ...overrides,
  });
}
function query(collectionId, where) {
  return { structuredQuery: { from: [{ collectionId }], ...(where ? { where } : {}) } };
}
function filter(fieldPath, op, input) { return { fieldFilter: { field: { fieldPath }, op, value: value(input) } }; }

test('personal UBAC and collaborative membership rules', { timeout: 180000 }, async (t) => {
  const a = await account('owner');
  const b = await account('member');
  const c = await account('outsider');
  const d = await account('extra-one');
  const personal = `tasks/${a.uid}-personal`;
  const aList = `collaborativeLists/${a.uid}`;
  const bList = `collaborativeLists/${b.uid}`;
  const shared = `${aList}/tasks/shared`;

  await t.test('personal CRUD remains strictly owner scoped, including queries', async () => {
    for (const actor of [a, b]) {
      const path = `tasks/${actor.uid}-personal`;
      await ok(write(path, actor, task(actor.uid)));
      await ok(read(path, actor));
      await ok(write(path, actor, task(actor.uid, { isDone: true })));
    }
    for (const actor of [b, c, null]) {
      await denied(read(personal, actor));
      await denied(write(personal, actor, task(a.uid, { title: 'Stolen' })));
      await denied(rest('DELETE', `/${personal}`, actor));
    }
    await denied(write(`tasks/${a.uid}-forged`, a, task(b.uid)));
    await denied(write(`tasks/${a.uid}-anonymous`, null, task(a.uid)));
    await denied(write(personal, a, task(b.uid)));
    await denied(write(`tasks/${a.uid}-bad-time`, a, task(a.uid, { dueTime: 1440 })));
    await denied(rest('POST', ':runQuery', a, query('tasks')));
    await ok(rest('POST', ':runQuery', a, query('tasks', filter('ownerId', 'EQUAL', a.uid))));
    await denied(rest('POST', ':runQuery', a, query('tasks', filter('ownerId', 'EQUAL', b.uid))));
    for (const actor of [a, b]) await ok(rest('DELETE', `/tasks/${actor.uid}-personal`, actor));
  });

  await t.test('default list initialization and owner metadata permissions', async () => {
    assert.equal((await read(aList, a)).status, 404, 'Owner can check own missing default list.');
    await denied(read(aList, b));
    await ok(write(aList, a, list(a.uid)));
    await ok(write(bList, b, list(b.uid)));
    const initializations = await Promise.all([d, d].map((actor) => rest('PATCH',
      `/collaborativeLists/${actor.uid}?currentDocument.exists=false`, actor, fields(list(actor.uid)))));
    assert.deepEqual(initializations.map((entry) => entry.status).sort(), [200, 409]);
    await ok(read(`collaborativeLists/${d.uid}`, d));
    await denied(write(aList, b, list(b.uid)));
    await denied(write(`collaborativeLists/forged-${a.uid}`, a, list(a.uid)));
    await denied(updateList(aList, a, { ownerId: b.uid }));
    await denied(updateList(aList, a, { memberIds: [b.uid] }));
    await denied(updateList(aList, a, { memberIds: [a.uid, a.uid] }));
    await ok(updateList(aList, a, { name: 'Renamed group' }));
    await denied(rest('DELETE', `/${aList}`, a));
    await denied(rest('POST', ':runQuery', a, query('collaborativeLists')));
    await ok(rest('POST', ':runQuery', a, query('collaborativeLists', filter('memberIds', 'ARRAY_CONTAINS', a.uid))));
  });

  await t.test('owners add and remove members by UID under Firestore rules', async () => {
    await denied(read(aList, b));
    await ok(updateList(aList, a, { memberIds: [a.uid, b.uid] }));
    await ok(read(aList, b));
    await ok(rest('POST', ':runQuery', b, query('collaborativeLists', filter('memberIds', 'ARRAY_CONTAINS', b.uid))));
    await denied(updateList(aList, b, { memberIds: [a.uid, b.uid, c.uid] }));
    await denied(updateList(aList, b, { name: 'Hijacked' }));
    await denied(read(aList, c));
    await ok(updateList(aList, a, { memberIds: [a.uid] }));
    await denied(read(aList, b));
    await ok(updateList(aList, a, { memberIds: [a.uid, b.uid] }));
  });

  await t.test('member discovery and shared CRUD use current parent membership', async () => {
    await ok(read(aList, b));
    await denied(read(bList, a));
    await ok(rest('POST', ':runQuery', b, query('collaborativeLists', filter('memberIds', 'ARRAY_CONTAINS', b.uid))));
    await denied(updateList(aList, b, { name: 'Hijacked' }));
    await ok(write(shared, a, task(a.uid)));
    await ok(read(shared, b));
    await ok(write(shared, b, task(a.uid, { title: 'Member edit', isDone: true })));
    await denied(write(shared, b, task(b.uid)));
    await denied(write(`${aList}/tasks/forged`, b, task(a.uid)));
    await denied(write(`${aList}/tasks/bad-time`, b, task(b.uid, { dueTime: 1440 })));
    await denied(write(shared, b, task(a.uid, { createdAt: new Date() })));
    for (const actor of [c, null]) {
      await denied(read(aList, actor));
      await denied(read(shared, actor));
      await denied(write(`${aList}/tasks/outsider`, actor, task(c.uid)));
      await denied(write(shared, actor, task(a.uid)));
      await denied(rest('DELETE', `/${shared}`, actor));
    }
    await ok(rest('POST', `/${aList}:runQuery`, b, query('tasks')));
    await denied(rest('POST', `/${bList}:runQuery`, a, query('tasks')));
    await ok(rest('DELETE', `/${shared}`, b));
    await ok(write(shared, b, task(b.uid)));
    await ok(rest('DELETE', `/${shared}`, a));
    await ok(write(shared, a, task(a.uid)));
    await ok(updateList(aList, a, { memberIds: [a.uid] }));
    await denied(read(aList, b));
    await denied(read(shared, b));
    await denied(write(shared, b, task(a.uid)));
    await denied(rest('DELETE', `/${shared}`, b));
    await denied(rest('POST', `/${aList}:runQuery`, b, query('tasks')));
  });

  await t.test('membership capacity and duplicate UIDs cannot be bypassed', async () => {
    const fullMembers = [a.uid, b.uid, ...Array.from({ length: 18 }, (_, i) => `synthetic-${i}`)];
    await ok(updateList(aList, a, { memberIds: fullMembers }));
    await denied(updateList(aList, a, { memberIds: [...fullMembers, c.uid] }));
    await denied(updateList(aList, a, { memberIds: [a.uid, a.uid] }));
    assert.equal((await adminDb.doc(aList).get()).data().memberIds.length, 20);
    await ok(updateList(aList, a, { memberIds: [a.uid] }));
    assert.deepEqual((await adminDb.doc(aList).get()).data().memberIds, [a.uid]);
  });
});
