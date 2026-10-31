import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/limits.dart';
import '../core/validation.dart';
import '../models/collaborative_list.dart';
import 'task_repository.dart';

abstract interface class CollaborationService {
  String get uid;
  Future<void> ensureDefaultList();
  Stream<List<CollaborativeList>> watchLists();
  TaskRepository tasksFor(String? listId);
  Future<String> addMember(String listId, String memberUid);
  Future<void> removeMember(String listId, String memberUid);
  Future<void> renameList(String listId, String name);

  /// Display names by UID. Accounts with no name to show are left out.
  Future<Map<String, String>> displayNames(List<String> uids);
}

class FirebaseCollaborationService implements CollaborationService {
  FirebaseCollaborationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance {
    uid = _auth.currentUser!.uid;
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  @override
  late final String uid;

  void _checkAccount() {
    if (_auth.currentUser?.uid != uid) {
      throw StateError('This account session has ended.');
    }
  }

  @override
  Future<void> ensureDefaultList() async {
    _checkAccount();
    final document = _firestore.collection('collaborativeLists').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(document);
      if (existing.exists) return;
      transaction.set(document, {
        'ownerId': uid,
        'name': 'My group',
        'memberIds': [uid],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Stream<List<CollaborativeList>> watchLists() {
    _checkAccount();
    return _firestore
        .collection('collaborativeLists')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final lists = snapshot.docs
              .map(CollaborativeList.fromFirestore)
              .toList();
          lists.sort((a, b) {
            if ((a.ownerId == uid) != (b.ownerId == uid)) {
              return a.ownerId == uid ? -1 : 1;
            }
            return a.name.compareTo(b.name);
          });
          return lists;
        });
  }

  @override
  TaskRepository tasksFor(String? listId) => FirestoreTaskRepository(
    firestore: _firestore,
    auth: _auth,
    listId: listId,
  );

  @override
  Future<String> addMember(String listId, String memberUid) async {
    _checkAccount();
    final cleaned = memberUid.trim();
    if (!isValidAccountUid(cleaned)) {
      throw const FormatException('Enter a valid account UID.');
    }
    if (cleaned == uid) return 'already-member';

    final document = _firestore.collection('collaborativeLists').doc(listId);
    return _firestore.runTransaction((transaction) async {
      final members = _ownedMembers(await transaction.get(document));
      if (members.contains(cleaned)) return 'already-member';
      if (members.length >= maxListMembers) {
        throw StateError('This list already has $maxListMembers members.');
      }
      transaction.update(document, {
        'memberIds': [...members, cleaned],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return 'added';
    });
  }

  @override
  Future<void> removeMember(String listId, String memberUid) async {
    _checkAccount();
    final document = _firestore.collection('collaborativeLists').doc(listId);
    await _firestore.runTransaction((transaction) async {
      final members = _ownedMembers(await transaction.get(document));
      if (memberUid == uid) throw StateError('The owner cannot be removed.');
      if (!members.contains(memberUid)) return;
      transaction.update(document, {
        'memberIds': members.where((member) => member != memberUid).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> renameList(String listId, String name) async {
    _checkAccount();
    final cleaned = name.trim();
    if (!isValidListName(cleaned)) {
      throw const FormatException(invalidListNameMessage);
    }
    final document = _firestore.collection('collaborativeLists').doc(listId);
    await _firestore.runTransaction((transaction) async {
      _ownedMembers(await transaction.get(document));
      transaction.update(document, {
        'name': cleaned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<Map<String, String>> displayNames(List<String> uids) async {
    _checkAccount();
    final profiles = _firestore.collection('publicProfiles');
    final documents = await Future.wait(
      uids.map((memberUid) => profiles.doc(memberUid).get()),
    );
    return {
      for (final document in documents)
        if (document.data()?['displayName'] case final String name
            when name.isNotEmpty)
          document.id: name,
    };
  }

  List<String> _ownedMembers(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists || snapshot.data()?['ownerId'] != uid) {
      throw StateError('You must own this list to change its members.');
    }
    final storedMembers = snapshot.data()!['memberIds'];
    if (storedMembers is! List ||
        storedMembers.any((member) => member is! String)) {
      throw StateError('This list has invalid membership data.');
    }
    final members = storedMembers.cast<String>();
    if (!members.contains(uid)) {
      throw StateError('This list has invalid membership data.');
    }
    return members;
  }
}
