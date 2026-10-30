import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/collaborative_list.dart';
import 'task_repository.dart';

abstract interface class CollaborationService {
  String get uid;
  bool get emailVerified;
  Future<void> ensureDefaultList();
  Stream<List<CollaborativeList>> watchLists();
  TaskRepository tasksFor(String? listId);
  Future<String> addMember(String listId, String email);
  Future<void> sendVerification();
  Future<bool> refreshVerification();
}

class FirebaseCollaborationService implements CollaborationService {
  FirebaseCollaborationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1') {
    uid = _auth.currentUser!.uid;
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  @override
  late final String uid;

  void _checkAccount() {
    if (_auth.currentUser?.uid != uid) {
      throw StateError('This account session has ended.');
    }
  }

  @override
  bool get emailVerified =>
      _auth.currentUser?.uid == uid && _auth.currentUser!.emailVerified;

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
  Future<String> addMember(String listId, String email) async {
    _checkAccount();
    await _auth.currentUser!.getIdToken(true);
    _checkAccount();
    final result = await _functions.httpsCallable('addListMember').call({
      'listId': listId,
      'email': email.trim(),
    });
    return (result.data as Map)['status'] as String;
  }

  @override
  Future<void> sendVerification() async {
    _checkAccount();
    await _auth.currentUser!.sendEmailVerification();
  }

  @override
  Future<bool> refreshVerification() async {
    _checkAccount();
    await _auth.currentUser!.reload();
    _checkAccount();
    await _auth.currentUser!.getIdToken(true);
    return emailVerified;
  }
}
