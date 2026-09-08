import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task.dart';

abstract interface class TaskRepository {
  Stream<List<Task>> watchTasks();

  Future<void> createTask(Task task);

  Future<void> updateTask(Task task);

  Future<void> deleteTask(Task task);
}

class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _tasks = (firestore ?? FirebaseFirestore.instance).collection('tasks'),
        _auth = auth ?? FirebaseAuth.instance;

  final CollectionReference<Map<String, dynamic>> _tasks;
  final FirebaseAuth _auth;

  User get _currentUser {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated Firebase user is available.');
    }
    return user;
  }

  @override
  Stream<List<Task>> watchTasks() => _tasks
      .where('ownerId', isEqualTo: _currentUser.uid)
      .snapshots()
      .map((snapshot) {
    final tasks = snapshot.docs.map(Task.fromFirestore).toList();
    tasks.sort((first, second) {
      if (first.isDone != second.isDone) return first.isDone ? 1 : -1;
      if (first.dueDate == null && second.dueDate == null) return 0;
      if (first.dueDate == null) return 1;
      if (second.dueDate == null) return -1;
      return first.dueDate!.compareTo(second.dueDate!);
    });
    return tasks;
      });

  @override
  Future<void> createTask(Task task) async {
    task.ownerId = _currentUser.uid;
    final document = await _tasks.add(task.toFirestore());
    task.id = document.id;
  }

  @override
  Future<void> updateTask(Task task) {
    final id = task.id;
    if (id == null) throw StateError('Cannot update a task without an ID.');
    task.ownerId = _currentUser.uid;
    return _tasks.doc(id).set(task.toFirestore());
  }

  @override
  Future<void> deleteTask(Task task) {
    final id = task.id;
    if (id == null) throw StateError('Cannot delete a task without an ID.');
    return _tasks.doc(id).delete();
  }
}
