import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/collaborative_list.dart';
import 'task_repository.dart';

const _maxMembers = 20;
final _memberIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

abstract interface class CollaborationService {
  String get uid;
  Future<void> ensureDefaultList();
  Stream<List<CollaborativeList>> watchLists();
  TaskRepository tasksFor(String? listId);
  Future<String> addMember(String listId, String memberUid);
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
    if (!_memberIdPattern.hasMatch(cleaned)) {
      throw const FormatException('Enter a valid account UID.');
    }
    if (cleaned == uid) return 'already-member';

    final document = _firestore.collection('collaborativeLists').doc(listId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      if (!snapshot.exists || snapshot.data()?['ownerId'] != uid) {
        throw StateError('You must own this list to add members.');
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
      if (members.contains(cleaned)) return 'already-member';
      if (members.length >= _maxMembers) {
        throw StateError('This list already has $_maxMembers members.');
      }
      transaction.update(document, {
        'memberIds': [...members, cleaned],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return 'added';
    });
  }
}
