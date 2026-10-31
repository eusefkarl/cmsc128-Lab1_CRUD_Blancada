import 'dart:async';

import 'package:do_it_now/models/collaborative_list.dart';
import 'package:do_it_now/models/task.dart';
import 'package:do_it_now/screens/collaborative_workspace.dart';
import 'package:do_it_now/services/collaboration_service.dart';
import 'package:do_it_now/services/task_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final subscription = changes.stream.listen(
        controller.add,
        onError: controller.addError,
      );
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
  Future<String> addMember(String listId, String memberUid) async {
    membersAdded.add('$listId:$memberUid');
    return 'added';
  }

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

Future<void> selectTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

Future<void> openGroup(WidgetTester tester, String name) async {
  await selectTab(tester, 'Groups');
  await tester.tap(find.widgetWithText(ListTile, name));
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
      await openGroup(tester, 'Joined group');
      expect(find.text('a-personal'), findsNothing);
      expect(find.text('a-joined'), findsOneWidget);
      expect(service.scopes['personal']!.cancelled, isTrue);
      expect(find.text('Add member'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Groups tab lists groups and navigates in and out of them', (
    tester,
  ) async {
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

    // Personal has no group controls; the old dropdown is gone.
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('All groups'), findsNothing);

    await selectTab(tester, 'Groups');
    expect(find.text('a-personal'), findsNothing);
    expect(find.text('Own group'), findsOneWidget);
    expect(find.text('Owner · 1/20 members'), findsOneWidget);
    expect(find.text('Joined group'), findsOneWidget);
    expect(find.text('Member · 2/20 members'), findsOneWidget);
    expect(find.byTooltip('Add task'), findsNothing);
    expect(find.byTooltip('Profile'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Own group'));
    await tester.pumpAndSettle();
    expect(find.text('a-a'), findsOneWidget);
    expect(find.text('Add member'), findsOneWidget);

    await tester.tap(find.text('All groups'));
    await tester.pumpAndSettle();
    expect(find.text('a-a'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Joined group'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Joined group'));
    await tester.pumpAndSettle();
    expect(find.text('a-joined'), findsOneWidget);

    // Tapping the active tab from inside a group also returns to the picker.
    await selectTab(tester, 'Groups');
    expect(find.text('a-joined'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Own group'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Joined group'));
    await tester.pumpAndSettle();
    await selectTab(tester, 'Personal');
    expect(find.text('a-joined'), findsNothing);
    expect(find.text('a-personal'), findsOneWidget);

    // Reopening Groups shows the picker rather than the previous group.
    await selectTab(tester, 'Groups');
    expect(find.text('a-joined'), findsNothing);
    expect(find.text('Your groups'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('groups with the same name are told apart by short ID', (
    tester,
  ) async {
    final service = FakeCollaboration('a');
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(home: CollaborativeWorkspace(service: service)),
    );
    await tester.pumpAndSettle();
    service.lists.add(const [
      CollaborativeList(
        id: 'a',
        ownerId: 'a',
        name: 'My group',
        memberIds: ['a'],
      ),
      CollaborativeList(
        id: 'ownerUid-with-long-id',
        ownerId: 'ownerUid-with-long-id',
        name: 'My group',
        memberIds: ['ownerUid-with-long-id', 'a'],
      ),
    ]);
    await tester.pumpAndSettle();
    await selectTab(tester, 'Groups');
    expect(find.text('Owner · 1/20 members · a'), findsOneWidget);
    expect(find.text('Member · 2/20 members · ownerUid'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Groups tab shows the account UID and copies it', (tester) async {
    final copied = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final service = FakeCollaboration('account-uid-123');
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(home: CollaborativeWorkspace(service: service)),
    );
    await tester.pumpAndSettle();
    await selectTab(tester, 'Groups');
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'account-uid-123',
    );
    await tester.tap(find.text('Copy UID'));
    await tester.pumpAndSettle();
    expect(copied, ['account-uid-123']);
    expect(find.text('Account UID copied.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed copy says so instead of claiming success', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'copy_fail');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final service = FakeCollaboration('a');
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(home: CollaborativeWorkspace(service: service)),
    );
    await tester.pumpAndSettle();
    await selectTab(tester, 'Groups');
    await tester.tap(find.text('Copy UID'));
    await tester.pumpAndSettle();
    expect(find.text('Account UID copied.'), findsNothing);
    expect(
      find.text('Could not copy. Select the UID and copy it manually.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a group stream failure stays on Groups and Retry reconnects', (
    tester,
  ) async {
    final service = FakeCollaboration('a');
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(home: CollaborativeWorkspace(service: service)),
    );
    await tester.pumpAndSettle();
    service.lists.add(service.groups);
    await tester.pumpAndSettle();
    await openGroup(tester, 'Joined group');

    service.lists.addError(StateError('offline'));
    await tester.pumpAndSettle();
    const message = 'Groups are unavailable. Retry to reconnect.';
    expect(find.text('a-joined'), findsNothing);
    expect(find.text(message), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Joined group'), findsNothing);

    // Personal tasks do not depend on the group stream.
    await selectTab(tester, 'Personal');
    expect(find.text('a-personal'), findsOneWidget);
    expect(find.text(message), findsNothing);

    await selectTab(tester, 'Groups');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
    expect(find.text('Your groups'), findsOneWidget);
    service.lists.add(service.groups);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Joined group'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Groups tab and group header reflow on a narrow display', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = FakeCollaboration('a-very-long-account-uid-1234567890');
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(320, 760),
            textScaler: const TextScaler.linear(2),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: CollaborativeWorkspace(service: service),
      ),
    );
    await tester.pumpAndSettle();
    service.lists.add(service.groups);
    await tester.pumpAndSettle();
    await selectTab(tester, 'Groups');
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Own group'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Own group'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Own group'));
    await tester.pumpAndSettle();
    expect(find.text('All groups'), findsOneWidget);
    expect(find.text('Add member'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('losing task permission in a group returns to the picker', (
    tester,
  ) async {
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
    await openGroup(tester, 'Joined group');
    service.scopes['joined']!.changes.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await tester.pumpAndSettle();
    expect(find.text('a-joined'), findsNothing);
    expect(find.text('Your groups'), findsOneWidget);
    expect(find.text('Access to that group ended.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
      await openGroup(tester, 'Joined group');
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsOneWidget);
      service.lists.add([service.groups.first]);
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsNothing);
      expect(find.text('a-joined'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Own group'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Joined group'), findsNothing);
      expect(find.text('Access to that group ended.'), findsOneWidget);
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
    await openGroup(tester, 'Joined group');
    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(home: CollaborativeWorkspace(service: second)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('a-joined'), findsNothing);
    expect(find.text('b-personal'), findsOneWidget);
    // Late old-account emissions cannot repopulate the picker.
    first.lists.add(first.groups);
    await tester.pumpAndSettle();
    await selectTab(tester, 'Groups');
    expect(find.text('Your groups'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Joined group'), findsNothing);
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
      await openGroup(tester, 'Joined group');
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
        await openGroup(tester, 'Joined group');
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        expect(service.scopes['joined']!.deleted, isEmpty);
        service.scopes['joined']!.rejectDelete = rejectDelete;
        await selectTab(tester, 'Personal');
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
        await openGroup(tester, 'Joined group');
        expect(
          find.text('a-joined'),
          rejectDelete ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('owners can invite a member by account UID', (tester) async {
    final service = FakeCollaboration('a');
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(home: CollaborativeWorkspace(service: service)),
    );
    await tester.pumpAndSettle();
    service.lists.add(service.groups);
    await tester.pumpAndSettle();
    await openGroup(tester, 'Own group');
    await tester.tap(find.text('Add member'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account UID'),
      'member-uid',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add member'));
    await tester.pumpAndSettle();
    expect(service.membersAdded, ['a:member-uid']);
    expect(find.text('Member added.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
