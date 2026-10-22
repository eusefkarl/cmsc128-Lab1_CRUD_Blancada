import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { test } from 'node:test';

// This suite deliberately refuses nonlocal endpoints. No production credentials
// or deployed service is needed; start Auth, Firestore and Functions emulators.
const require = createRequire(new URL('../functions/package.json', import.meta.url));
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const project = process.env.GCLOUD_PROJECT || 'doitnow-c26f9';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
for (const host of [authHost, firestoreHost, functionsHost]) {
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

async function account(label, verified = true) {
  const email = `${label}-${Date.now()}-${sequence++}@example.test`;
  const created = await adminAuth.createUser({ email, password, emailVerified: verified });
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
async function call(actor, data) {
  const response = await fetch(`http://${functionsHost}/${project}/us-central1/addListMember`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(actor ? { authorization: `Bearer ${actor.token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  return response.json();
}
async function callError(actor, data, status) {
  assert.equal((await call(actor, data)).error?.status, status);
}
function task(uid, overrides = {}) {
  return { ownerId: uid, title: 'Synthetic task', details: '', createdAt: new Date('2026-01-01T00:00:00Z'),
    dueDate: null, dueTime: null, priority: 'medium', category: 'school', isDone: false, ...overrides };
}
function list(uid, overrides = {}) {
  return { ownerId: uid, name: 'My group', memberIds: [uid], createdAt: new Date(), updatedAt: new Date(), ...overrides };
}
function query(collectionId, where) {
  return { structuredQuery: { from: [{ collectionId }], ...(where ? { where } : {}) } };
}
function filter(fieldPath, op, input) { return { fieldFilter: { field: { fieldPath }, op, value: value(input) } }; }

test('personal UBAC, collaborative rules and callable adversarial acceptance', { timeout: 180000 }, async (t) => {
  const a = await account('owner');
  const b = await account('member');
  const c = await account('outsider');
  const d = await account('capacity-one');
  const e = await account('capacity-two');
  const unverified = await account('unverified', false);
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
    await denied(write(`collaborativeLists/${c.uid}`, c, list(c.uid, { memberIds: [c.uid, a.uid] })));
    await denied(write(`collaborativeLists/forged-${a.uid}`, a, list(a.uid)));
    await denied(write(aList, a, list(b.uid)));
    await denied(write(aList, a, list(a.uid, { memberIds: [a.uid, b.uid] })));
    const saved = (await adminDb.doc(aList).get()).data();
    await ok(write(aList, a, { ...saved, createdAt: saved.createdAt.toDate(), updatedAt: new Date(), name: 'Renamed group' }));
    await denied(rest('DELETE', `/${aList}`, a));
    await denied(rest('POST', ':runQuery', a, query('collaborativeLists')));
    await ok(rest('POST', ':runQuery', a, query('collaborativeLists', filter('memberIds', 'ARRAY_CONTAINS', a.uid))));
  });

  await t.test('callable authenticates, verifies, validates and checks owner before lookup', async () => {
    await callError(null, { listId: a.uid, email: b.email }, 'UNAUTHENTICATED');
    await callError(unverified, { listId: a.uid, email: b.email }, 'FAILED_PRECONDITION');
    await callError(b, { listId: a.uid, email: 'missing@example.test' }, 'PERMISSION_DENIED');
    await callError(c, { listId: 'missing', email: a.email }, 'PERMISSION_DENIED');
    for (const input of [{ listId: '../users', email: b.email }, { listId: a.uid, email: 'bad' },
      { listId: a.uid, email: b.email, ownerId: a.uid }, null]) {
      await callError(a, input, 'INVALID_ARGUMENT');
    }
    await callError(a, { listId: a.uid, email: 'missing@example.test' }, 'NOT_FOUND');
    assert.equal((await call(a, { listId: a.uid, email: a.email })).result?.status, 'already-member');
    const results = await Promise.all(Array.from({ length: 3 }, () => call(a, { listId: a.uid, email: b.email })));
    assert.equal(results.filter((entry) => entry.result?.status === 'added').length, 1);
    assert.equal(results.filter((entry) => entry.result?.status === 'already-member').length, 2);
    assert.deepEqual((await adminDb.doc(aList).get()).data().memberIds, [a.uid, b.uid]);
    await denied(read(`users/${b.uid}`, a));
    await denied(read(`_invitationLimits/${a.uid}`, a));
    await denied(write(`_invitationLimits/${a.uid}`, a, { count: 0 }));
  });

  await t.test('member discovery and shared CRUD use current parent membership', async () => {
    await ok(read(aList, b));
    await denied(read(bList, a));
    await ok(rest('POST', ':runQuery', b, query('collaborativeLists', filter('memberIds', 'ARRAY_CONTAINS', b.uid))));
    await denied(write(aList, b, list(a.uid, { memberIds: [a.uid, b.uid], name: 'Hijacked' })));
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
    await adminDb.doc(aList).update({ memberIds: [a.uid] });
    await denied(read(aList, b));
    await denied(read(shared, b));
    await denied(write(shared, b, task(a.uid)));
    await denied(rest('DELETE', `/${shared}`, b));
    await denied(rest('POST', `/${aList}:runQuery`, b, query('tasks')));
  });

  await t.test('changed email resolves stable UID, disabled accounts cannot join', async () => {
    const changed = `changed-${Date.now()}@example.test`;
    await adminAuth.updateUser(b.uid, { email: changed });
    b.email = changed;
    assert.equal((await call(a, { listId: a.uid, email: changed })).result?.status, 'added');
    assert.equal((await call(a, { listId: a.uid, email: changed })).result?.status, 'already-member');
    assert.deepEqual((await adminDb.doc(aList).get()).data().memberIds, [a.uid, b.uid]);
    await adminAuth.updateUser(c.uid, { disabled: true });
    await callError(a, { listId: a.uid, email: c.email }, 'FAILED_PRECONDITION');
  });

  await t.test('group capacity and persisted quota cannot be bypassed', async () => {
    const fullMembers = [a.uid, b.uid, ...Array.from({ length: 18 }, (_, i) => `synthetic-${i}`)];
    await adminDb.doc(aList).update({ memberIds: fullMembers });
    assert.equal((await call(a, { listId: a.uid, email: b.email })).result?.status, 'already-member');
    await callError(a, { listId: a.uid, email: d.email }, 'RESOURCE_EXHAUSTED');
    assert.equal((await adminDb.doc(aList).get()).data().memberIds.length, 20);
    await adminDb.doc(aList).update({ memberIds: fullMembers.slice(0, 19) });
    const additions = await Promise.all([d, e].map((actor) => call(a, { listId: a.uid, email: actor.email })));
    assert.equal(additions.filter((entry) => entry.result?.status === 'added').length, 1);
    assert.equal(additions.filter((entry) => entry.error?.status === 'RESOURCE_EXHAUSTED').length, 1);
    assert.equal((await adminDb.doc(aList).get()).data().memberIds.length, 20);
    await adminDb.doc(aList).update({ memberIds: [a.uid] });
    await adminDb.doc(`_invitationLimits/${a.uid}`).set({ windowStart: Timestamp.now(), count: 19 });
    const results = await Promise.all([call(a, { listId: a.uid, email: b.email }), call(a, { listId: a.uid, email: b.email })]);
    assert.equal(results.filter((entry) => entry.result).length, 1);
    assert.equal(results.filter((entry) => entry.error?.status === 'RESOURCE_EXHAUSTED').length, 1);
    assert.equal((await adminDb.doc(`_invitationLimits/${a.uid}`).get()).data().count, 20);
    await adminDb.doc(`_invitationLimits/${a.uid}`).set({ windowStart: Timestamp.fromMillis(Date.now() - 3600001), count: 20 });
    assert.equal((await call(a, { listId: a.uid, email: b.email })).result?.status, 'already-member');
  });
});
