import 'dart:async';

import 'package:do_it_now/models/collaborative_list.dart';
import 'package:do_it_now/models/task.dart';
import 'package:do_it_now/screens/collaborative_workspace.dart';
import 'package:do_it_now/services/collaboration_service.dart';
import 'package:do_it_now/services/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ScopeTasks implements TaskRepository {
  ScopeTasks(this.label);
  final String label;
  final changes = StreamController<List<Task>>.broadcast();
  final created = <Task>[];
  final deleted = <Task>[];
  bool _deleted = false;
  bool cancelled = false;
  bool rejectDelete = false;

  @override
  Stream<List<Task>> watchTasks() {
    final controller = StreamController<List<Task>>();
    controller.onListen = () {
      controller.add(
        _deleted
            ? []
            : [
                Task(
                  id: label,
                  ownerId: 'original-creator',
                  title: label,
                  details: '',
                ),
              ],
      );
      final subscription = changes.stream.listen(controller.add);
      controller.onCancel = () {
        cancelled = true;
        return subscription.cancel();
      };
    };
    return controller.stream;
  }

  @override
  Future<void> createTask(Task task) async => created.add(task);
  @override
  Future<void> deleteTask(Task task) {
    if (rejectDelete) throw StateError('Session ended');
    deleted.add(task);
    _deleted = true;
    changes.add([]);
    return Future.value();
  }

  @override
  Future<void> updateTask(Task task) async {}
}

class FakeCollaboration implements CollaborationService {
  FakeCollaboration(this.uid);
  @override
  final String uid;
  @override
  bool emailVerified = true;
  int verificationSent = 0;
  final membersAdded = <String>[];
  final lists = StreamController<List<CollaborativeList>>.broadcast();
  final scopes = <String, ScopeTasks>{};
  bool initialized = false;

  @override
  Future<void> ensureDefaultList() async => initialized = true;
  @override
  Stream<List<CollaborativeList>> watchLists() => lists.stream;
  @override
  TaskRepository tasksFor(String? listId) => scopes.putIfAbsent(
    listId ?? 'personal',
    () => ScopeTasks('$uid-${listId ?? 'personal'}'),
  );
  @override
  Future<String> addMember(String listId, String email) async {
    membersAdded.add('$listId:$email');
    return 'added';
  }

  @override
  Future<void> sendVerification() async => verificationSent++;
  @override
  Future<bool> refreshVerification() async => emailVerified = true;

  List<CollaborativeList> get groups => [
    CollaborativeList(
      id: uid,
      ownerId: uid,
      name: 'Own group',
      memberIds: [uid],
    ),
    CollaborativeList(
      id: 'joined',
      ownerId: 'someone-else',
      name: 'Joined group',
      memberIds: ['someone-else', uid],
    ),
  ];

  Future<void> close() async {
    await lists.close();
    for (final scope in scopes.values) {
      await scope.changes.close();
    }
  }
}

Future<void> selectList(WidgetTester tester, String text) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'switching lists cancels the old stream and clears protected records',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = FakeCollaboration('a');
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(home: CollaborativeWorkspace(service: service)),
      );
      await tester.pumpAndSettle();
      service.lists.add(service.groups);
      await tester.pumpAndSettle();
      expect(service.initialized, isTrue);
      expect(find.text('a-personal'), findsOneWidget);
      await selectList(tester, 'Joined group · Joined');
      expect(find.text('a-personal'), findsNothing);
      expect(find.text('a-joined'), findsOneWidget);
      expect(service.scopes['personal']!.cancelled, isTrue);
      expect(find.text('Add member'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'membership revocation closes an edit form without saving and falls back',
    (tester) async {
      final service = FakeCollaboration('a');
      addTearDown(service.close);
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: CollaborativeWorkspace(service: service)),
      );
      await tester.pumpAndSettle();
      service.lists.add(service.groups);
      await tester.pumpAndSettle();
      await selectList(tester, 'Joined group · Joined');
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsOneWidget);
      service.lists.add([service.groups.first]);
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsNothing);
      expect(find.text('a-joined'), findsNothing);
      expect(find.text('a-personal'), findsOneWidget);
      expect(service.scopes['joined']!.cancelled, isTrue);
      expect(service.scopes['joined']!.created, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('account replacement clears old lists and open protected forms', (
    tester,
  ) async {
    final first = FakeCollaboration('a');
    final second = FakeCollaboration('b');
    addTearDown(first.close);
    addTearDown(second.close);
    await tester.pumpWidget(
      MaterialApp(home: CollaborativeWorkspace(service: first)),
    );
    await tester.pumpAndSettle();
    first.lists.add(first.groups);
    await tester.pumpAndSettle();
    await selectList(tester, 'Joined group · Joined');
    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(home: CollaborativeWorkspace(service: second)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('a-joined'), findsNothing);
    expect(find.text('b-personal'), findsOneWidget);
    expect(find.text('Joined group · Joined'), findsNothing);
    // Late old-account emissions cannot repopulate the selector.
    first.lists.add(first.groups);
    await tester.pumpAndSettle();
    expect(find.text('Joined group · Joined'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final picker in ['Due date', 'Due time']) {
    testWidgets('revocation closes the nested $picker picker safely', (
      tester,
    ) async {
      final service = FakeCollaboration('a');
      addTearDown(service.close);
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: CollaborativeWorkspace(service: service)),
      );
      await tester.pumpAndSettle();
      service.lists.add(service.groups);
      await tester.pumpAndSettle();
      await selectList(tester, 'Joined group · Joined');
      await tester.tap(find.byTooltip('Add task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(picker));
      await tester.pumpAndSettle();
      expect(
        picker == 'Due date'
            ? find.byType(DatePickerDialog)
            : find.byType(TimePickerDialog),
        findsOneWidget,
      );
      service.lists.add([service.groups.first]);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(service.scopes['joined']!.created, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final rejectDelete in [false, true]) {
    testWidgets(
      'switching scopes finalizes pending deletion safely (failure: $rejectDelete)',
      (tester) async {
        final service = FakeCollaboration('a');
        addTearDown(service.close);
        await tester.binding.setSurfaceSize(const Size(1000, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(home: CollaborativeWorkspace(service: service)),
        );
        await tester.pumpAndSettle();
        service.lists.add(service.groups);
        await tester.pumpAndSettle();
        await selectList(tester, 'Joined group · Joined');
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        expect(service.scopes['joined']!.deleted, isEmpty);
        service.scopes['joined']!.rejectDelete = rejectDelete;
        await selectList(tester, 'Personal');
        if (rejectDelete) {
          expect(
            find.text(
              'Could not complete a deletion in the previous list. Reopen it to retry.',
            ),
            findsOneWidget,
          );
        } else {
          expect(service.scopes['joined']!.deleted.single.id, 'a-joined');
        }
        expect(service.scopes['personal']!.deleted, isEmpty);
        await tester.pump(const Duration(seconds: 6));
        expect(
          service.scopes['joined']!.deleted,
          hasLength(rejectDelete ? 0 : 1),
        );
        await selectList(tester, 'Joined group · Joined');
        expect(
          find.text('a-joined'),
          rejectDelete ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('unverified owners can verify and invite by registered email', (
    tester,
  ) async {
    final service = FakeCollaboration('a')..emailVerified = false;
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(home: CollaborativeWorkspace(service: service)),
    );
    await tester.pumpAndSettle();
    service.lists.add(service.groups);
    await tester.pumpAndSettle();
    await selectList(tester, 'Own group · Owned');
    await tester.tap(find.text('Add member'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add member'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Send verification email'));
    await tester.pumpAndSettle();
    expect(service.verificationSent, 1);
    await tester.tap(find.text('Check verification'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Registered email'),
      'member@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add member'));
    await tester.pumpAndSettle();
    expect(service.membersAdded, ['a:member@example.com']);
    expect(find.text('Member added.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
