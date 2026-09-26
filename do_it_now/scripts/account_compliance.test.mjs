import assert from 'node:assert/strict';
import { test } from 'node:test';

const projectId = 'doitnow-c26f9';
const apiKey = 'fake-api-key';
const authBase = 'http://127.0.0.1:9099';
const firestoreBase = 'http://127.0.0.1:8080';
const oldPassword = 'Old-password-123';
let emailSequence = 0;

class EmulatorError extends Error {
  constructor(response, payload) {
    super(payload?.error?.message ?? `Emulator request failed (${response.status}).`);
    this.status = response.status;
    this.code = payload?.error?.status;
  }
}

function uniqueEmail(label) {
  emailSequence += 1;
  return `${label}-${Date.now()}-${emailSequence}@example.test`;
}

async function authRequest(endpoint, body) {
  const response = await fetch(
    `${authBase}/identitytoolkit.googleapis.com/v1/${endpoint}?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    },
  );
  const payload = await response.json();
  if (!response.ok) throw new EmulatorError(response, payload);
  return payload;
}

async function signUp(email, password = oldPassword) {
  return authRequest('accounts:signUp', {
    email,
    password,
    returnSecureToken: true,
  });
}

async function signIn(email, password = oldPassword) {
  return authRequest('accounts:signInWithPassword', {
    email,
    password,
    returnSecureToken: true,
  });
}

async function readActionCodes() {
  const response = await fetch(
    `${authBase}/emulator/v1/projects/${projectId}/oobCodes`,
  );
  if (!response.ok) {
    throw new Error(`Could not read Auth emulator codes (${response.status}).`);
  }
  return (await response.json()).oobCodes ?? [];
}

async function waitForActionCode(email, requestType) {
  let lastCodes = [];
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const codes = await readActionCodes();
    lastCodes = codes;
    const code = codes.find(
      (entry) =>
        (entry.email === email || entry.newEmail === email) &&
        entry.requestType === requestType,
    );
    if (code) return code.oobCode;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(
    `No ${requestType} action code was created for ${email}. Found: ${JSON.stringify(lastCodes)}`,
  );
}

function firestoreDocumentPath(uid) {
  return `/v1/projects/${projectId}/databases/(default)/documents/users/${encodeURIComponent(uid)}`;
}

function firestoreFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [
      key,
      typeof value === 'string'
        ? { stringValue: value }
        : { timestampValue: value.toISOString() },
    ]),
  );
}

async function firestoreRequest(method, path, idToken, body, query = '') {
  const response = await fetch(`${firestoreBase}${path}${query}`, {
    method,
    headers: {
      authorization: `Bearer ${idToken}`,
      ...(body ? { 'content-type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const payload = response.status === 204 ? null : await response.json();
  return { response, payload };
}

async function createProfile(user, email, displayName) {
  const now = new Date();
  return firestoreRequest(
    'POST',
    `/v1/projects/${projectId}/databases/(default)/documents/users?documentId=${encodeURIComponent(user.localId)}`,
    user.idToken,
    {
      fields: firestoreFields({
        uid: user.localId,
        email,
        displayName,
        createdAt: now,
        updatedAt: now,
      }),
    },
  );
}

async function readProfile(uid, idToken) {
  const { response, payload } = await firestoreRequest(
    'GET',
    firestoreDocumentPath(uid),
    idToken,
  );
  if (!response.ok) throw new EmulatorError(response, payload);
  return Object.fromEntries(
    Object.entries(payload.fields ?? {}).map(([key, value]) => [
      key,
      value.stringValue ?? value.timestampValue,
    ]),
  );
}

test('verified email change updates the account and permits only the verified Firestore email', async () => {
  const oldEmail = uniqueEmail('email-before');
  const newEmail = uniqueEmail('email-after');
  const user = await signUp(oldEmail);
  const profileCreate = await createProfile(user, oldEmail, 'Compliance user');
  assert.equal(profileCreate.response.status, 200);

  const sent = await authRequest('accounts:sendOobCode', {
    requestType: 'VERIFY_AND_CHANGE_EMAIL',
    idToken: user.idToken,
    newEmail,
  });
  assert.equal(typeof sent.email, 'string');

  const oldProfile = await readProfile(user.localId, user.idToken);
  assert.equal(oldProfile.email, oldEmail);

  const tamperedWrite = await firestoreRequest(
    'PATCH',
    firestoreDocumentPath(user.localId),
    user.idToken,
    { fields: { email: { stringValue: newEmail } } },
    '?updateMask.fieldPaths=email',
  );
  assert.equal(tamperedWrite.response.status, 403);

  const code = await waitForActionCode(newEmail, 'VERIFY_AND_CHANGE_EMAIL');
  await authRequest('accounts:update', { oobCode: code });
  await assert.rejects(signIn(oldEmail), EmulatorError);

  const updatedUser = await signIn(newEmail);
  const profileSync = await firestoreRequest(
    'PATCH',
    firestoreDocumentPath(user.localId),
    updatedUser.idToken,
    {
      fields: firestoreFields({
        uid: user.localId,
        email: newEmail,
        displayName: 'Compliance user',
        createdAt: new Date(oldProfile.createdAt),
        updatedAt: new Date(),
      }),
    },
  );
  assert.equal(profileSync.response.status, 200);
  const syncedProfile = await readProfile(user.localId, updatedUser.idToken);
  assert.equal(syncedProfile.email, newEmail);
  assert.equal(syncedProfile.displayName, 'Compliance user');
  assert.equal(
    Object.keys(syncedProfile).some((key) =>
      key.toLowerCase().includes('password'),
    ),
    false,
  );
});

test('Firebase Auth rejects duplicate email changes and incorrect credentials', async () => {
  const accountEmail = uniqueEmail('account');
  const reservedEmail = uniqueEmail('reserved');
  const account = await signUp(accountEmail);
  await signUp(reservedEmail);

  await assert.rejects(
    authRequest('accounts:sendOobCode', {
      requestType: 'VERIFY_AND_CHANGE_EMAIL',
      idToken: account.idToken,
      newEmail: reservedEmail,
    }),
    (error) => error instanceof EmulatorError && /EMAIL_EXISTS/.test(error.message),
  );
  await assert.rejects(signIn(accountEmail, 'incorrect-password'), EmulatorError);
});

test('display name persists in Firebase Auth and the profile mirror without storing passwords', async () => {
  const email = uniqueEmail('display-name');
  const user = await signUp(email);
  const created = await createProfile(user, email, 'Original name');
  assert.equal(created.response.status, 200);

  const updatedAuthUser = await authRequest('accounts:update', {
    idToken: user.idToken,
    displayName: 'Updated display name',
    returnSecureToken: true,
  });
  const signedIn = await signIn(email);
  const synced = await firestoreRequest(
    'PATCH',
    firestoreDocumentPath(user.localId),
    signedIn.idToken,
    {
      fields: {
        displayName: { stringValue: 'Updated display name' },
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    },
    '?updateMask.fieldPaths=displayName&updateMask.fieldPaths=updatedAt',
  );
  assert.equal(
    synced.response.status,
    200,
    JSON.stringify(synced.payload),
  );

  const profile = await readProfile(user.localId, signedIn.idToken);
  const authProfile = await authRequest('accounts:lookup', {
    idToken: signedIn.idToken,
  });
  assert.equal(authProfile.users[0].displayName, 'Updated display name');
  assert.equal(profile.displayName, 'Updated display name');
  assert.equal(
    Object.keys(profile).some((key) => key.toLowerCase().includes('password')),
    false,
  );
});

test('password changes and recovery make the new password work and the old one fail', async () => {
  const changedEmail = uniqueEmail('changed-password');
  const user = await signUp(changedEmail);
  const recentLogin = await signIn(changedEmail);
  const directPassword = 'New-password-456';

  await authRequest('accounts:update', {
    idToken: recentLogin.idToken,
    password: directPassword,
    returnSecureToken: true,
  });
  await assert.rejects(signIn(changedEmail, oldPassword), EmulatorError);
  await signIn(changedEmail, directPassword);

  const resetEmail = uniqueEmail('reset-password');
  await signUp(resetEmail);
  await authRequest('accounts:sendOobCode', {
    requestType: 'PASSWORD_RESET',
    email: resetEmail,
  });
  const resetCode = await waitForActionCode(resetEmail, 'PASSWORD_RESET');
  const verifiedCode = await authRequest('accounts:resetPassword', {
    oobCode: resetCode,
  });
  assert.equal(verifiedCode.email, resetEmail);

  const recoveredPassword = 'Recovered-password-789';
  await authRequest('accounts:resetPassword', {
    oobCode: resetCode,
    newPassword: recoveredPassword,
  });
  await assert.rejects(
    authRequest('accounts:resetPassword', { oobCode: resetCode }),
    EmulatorError,
  );
  await assert.rejects(
    authRequest('accounts:resetPassword', { oobCode: 'invalid-action-code' }),
    EmulatorError,
  );
  await assert.rejects(signIn(resetEmail, oldPassword), EmulatorError);
  await signIn(resetEmail, recoveredPassword);
});
