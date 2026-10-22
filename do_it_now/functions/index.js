'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');
const { HttpsError, onCall } = require('firebase-functions/v2/https');

initializeApp();
const db = getFirestore();
const MAX_MEMBERS = 20;
const RATE_LIMIT = 20;
const RATE_WINDOW_MS = 60 * 60 * 1000;

function assertOwnedList(snapshot, uid) {
  if (!snapshot.exists || snapshot.data().ownerId !== uid) {
    // Do not distinguish an inaccessible list from a nonexistent list.
    throw new HttpsError('permission-denied', 'You must own this list to add members.');
  }
  const members = snapshot.data().memberIds;
  if (!Array.isArray(members) || !members.includes(uid) || members.length > MAX_MEMBERS) {
    throw new HttpsError('failed-precondition', 'This list has invalid membership data.');
  }
  return members;
}

exports.addListMember = onCall({ region: 'us-central1', maxInstances: 5 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in to add a member.');
  if (request.auth.token.email_verified !== true) {
    throw new HttpsError('failed-precondition', 'Verify your email before adding members.');
  }
  const data = request.data;
  if (!data || typeof data !== 'object' || Array.isArray(data)
      || Object.keys(data).some((key) => !['listId', 'email'].includes(key))
      || typeof data.listId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(data.listId)
      || typeof data.email !== 'string') {
    throw new HttpsError('invalid-argument', 'Provide a valid list ID and registered email.');
  }
  const email = data.email.trim();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError('invalid-argument', 'Enter a valid email address.');
  }
  const listRef = db.collection('collaborativeLists').doc(data.listId);
  const rateRef = db.collection('_invitationLimits').doc(uid);

  // Persist the quota before Auth lookup. Failed and duplicate lookups also count,
  // and concurrent requests cannot race around the per-requester hourly limit.
  await db.runTransaction(async (transaction) => {
    const [list, rate] = await Promise.all([transaction.get(listRef), transaction.get(rateRef)]);
    assertOwnedList(list, uid);
    const now = Date.now();
    const previous = rate.data();
    const sameWindow = previous?.windowStart instanceof Timestamp
      && now - previous.windowStart.toMillis() < RATE_WINDOW_MS;
    const count = sameWindow ? previous.count : 0;
    if (count >= RATE_LIMIT) {
      throw new HttpsError('resource-exhausted', 'Invitation limit reached. Try again later.');
    }
    transaction.set(rateRef, {
      windowStart: sameWindow ? previous.windowStart : Timestamp.fromMillis(now),
      count: count + 1,
    });
  });

  let member;
  try {
    member = await getAuth().getUserByEmail(email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError('not-found', 'No registered account uses that email.');
    }
    throw new HttpsError('internal', 'Could not add the member. Try again later.');
  }
  if (member.disabled) {
    throw new HttpsError('failed-precondition', 'That account cannot join a list.');
  }

  return db.runTransaction(async (transaction) => {
    const members = assertOwnedList(await transaction.get(listRef), uid);
    if (members.includes(member.uid)) {
      return { status: 'already-member', memberCount: members.length };
    }
    if (members.length >= MAX_MEMBERS) {
      throw new HttpsError('resource-exhausted', 'This list already has 20 members.');
    }
    transaction.update(listRef, {
      memberIds: [...members, member.uid],
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { status: 'added', memberCount: members.length + 1 };
  });
});
