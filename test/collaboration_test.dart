import 'dart:async';

import 'package:do_it_now/core/validation.dart';
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
  final membersRemoved = <String>[];
  Object? removeError;
  final names = <String, String>{};
  Object? namesError;
  Completer<void>? namesGate;
  final renames = <String>[];
  Object? renameError;
  Completer<void>? actionGate;
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
    await actionGate?.future;
    membersAdded.add('$listId:$memberUid');
    return 'added';
  }

  @override
  Future<void> removeMember(String listId, String memberUid) async {
    if (removeError != null) throw removeError!;
    membersRemoved.add('$listId:$memberUid');
  }

  @override
  Future<void> renameList(String listId, String name) async {
    await actionGate?.future;
    if (renameError != null) throw renameError!;
    renames.add('$listId:$name');
  }

  @override
  Future<Map<String, String>> displayNames(List<String> uids) async {
    await namesGate?.future;
    if (namesError != null) throw namesError!;
    return {
      for (final id in uids)
        if (names[id] != null) id: names[id]!,
    };
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
      expect(find.text('Manage members'), findsNothing);
      expect(find.text('Rename group'), findsNothing);
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
    expect(find.text('Manage members'), findsOneWidget);

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
    await tester.tap(find.text('Manage members'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
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
    await tester.tap(find.text('Manage members'));
    await tester.pumpAndSettle();
    expect(find.text('Current members (1/20)'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account UID'),
      '  member-uid ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add member'));
    await tester.pumpAndSettle();
    expect(service.membersAdded, ['a:member-uid']);
    expect(find.text('Member added.'), findsOneWidget);
    expect(find.text('Current members (2/20)'), findsOneWidget);
    expect(find.byTooltip('Remove member'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('member names', () {
    Future<void> openMembersOf(
      WidgetTester tester,
      FakeCollaboration service,
      List<String> memberIds, {
      bool settle = true,
    }) async {
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(home: CollaborativeWorkspace(service: service)),
      );
      await tester.pumpAndSettle();
      service.lists.add([
        CollaborativeList(
          id: 'a',
          ownerId: 'a',
          name: 'Own group',
          memberIds: memberIds,
        ),
      ]);
      await tester.pumpAndSettle();
      await openGroup(tester, 'Own group');
      await tester.tap(find.text('Manage members'));
      if (settle) await tester.pumpAndSettle();
    }

    testWidgets('members are listed by display name instead of UID', (
      tester,
    ) async {
      final service = FakeCollaboration('a')
        ..names.addAll({'a': 'Ari', 'member-uid': 'Bo'});
      await openMembersOf(tester, service, ['a', 'member-uid']);
      expect(find.text('Ari (owner)'), findsOneWidget);
      expect(find.text('Bo'), findsOneWidget);
      expect(find.text('member-uid'), findsNothing);
      expect(find.textContaining('Unknown account'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a UID with no profile is flagged so a typo can be spotted', (
      tester,
    ) async {
      final service = FakeCollaboration('a')..names['a'] = 'Ari';
      await openMembersOf(tester, service, ['a', 'typo-uid']);
      expect(find.text('Unknown account · typo-uid'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('members with the same name are told apart by short ID', (
      tester,
    ) async {
      final service = FakeCollaboration('a')
        ..names.addAll({
          'a': 'Ari',
          'first-account-uid': 'Bo',
          'second-account-uid': 'Bo',
        });
      await openMembersOf(tester, service, [
        'a',
        'first-account-uid',
        'second-account-uid',
      ]);
      expect(find.text('Ari (owner)'), findsOneWidget);
      expect(find.text('Bo · first-ac'), findsOneWidget);
      expect(find.text('Bo · second-a'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a failed lookup falls back to UIDs and says so', (
      tester,
    ) async {
      final service = FakeCollaboration('a')
        ..namesError = StateError('offline');
      await openMembersOf(tester, service, ['a', 'member-uid']);
      expect(
        find.text('Member names could not be loaded, so UIDs are shown.'),
        findsOneWidget,
      );
      expect(find.text('a (owner)'), findsOneWidget);
      expect(find.text('member-uid'), findsOneWidget);
      // A failed lookup must not claim the account is unknown.
      expect(find.textContaining('Unknown account'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('names show a loading state until the lookup finishes', (
      tester,
    ) async {
      final gate = Completer<void>();
      final service = FakeCollaboration('a')
        ..names.addAll({'a': 'Ari', 'member-uid': 'Bo'})
        ..namesGate = gate;
      await openMembersOf(tester, service, ['a', 'member-uid'], settle: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Loading name…'), findsNWidgets(2));
      expect(find.text('member-uid'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Loading name…'), findsNothing);
      expect(find.text('Bo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('adding locks the field without toggling readOnly', (
      tester,
    ) async {
      final service = FakeCollaboration('a')..names['a'] = 'Ari';
      await openMembersOf(tester, service, ['a']);
      service.actionGate = Completer<void>();
      final field = find.widgetWithText(TextFormField, 'Account UID');
      await tester.enterText(field, 'new-uid');
      await tester.tap(find.widgetWithText(FilledButton, 'Add member'));
      await tester.pump();
      await tester.pump();
      final editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.readOnly, isFalse);
      expect(editable.focusNode.hasFocus, isFalse);
      expect(service.membersAdded, isEmpty);
      service.actionGate!.complete();
      await tester.pumpAndSettle();
      expect(service.membersAdded, ['a:new-uid']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a newly added member is listed by name', (tester) async {
      final service = FakeCollaboration('a')
        ..names.addAll({'a': 'Ari', 'new-uid': 'Cy'});
      await openMembersOf(tester, service, ['a']);
      expect(find.text('Cy'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Account UID'),
        'new-uid',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add member'));
      await tester.pumpAndSettle();
      expect(service.membersAdded, ['a:new-uid']);
      expect(find.text('Cy'), findsOneWidget);
      expect(find.text('Member added.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('group naming', () {
    const ownGroup = CollaborativeList(
      id: 'a',
      ownerId: 'a',
      name: 'Own group',
      memberIds: ['a'],
    );
    final field = find.widgetWithText(TextFormField, 'Group name');
    final save = find.widgetWithText(FilledButton, 'Save');

    Future<FakeCollaboration> openRename(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = FakeCollaboration('a');
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(home: CollaborativeWorkspace(service: service)),
      );
      await tester.pumpAndSettle();
      service.lists.add(const [ownGroup]);
      await tester.pumpAndSettle();
      await openGroup(tester, 'Own group');
      await tester.tap(find.text('Rename group'));
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets('owners rename a group and it stays open', (tester) async {
      final service = await openRename(tester);
      expect(tester.widget<TextFormField>(field).controller!.text, 'Own group');
      await tester.enterText(field, '  Study squad ');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(service.renames, ['a:Study squad']);
      expect(find.byType(AlertDialog), findsNothing);

      service.lists.add(const [
        CollaborativeList(
          id: 'a',
          ownerId: 'a',
          name: 'Study squad',
          memberIds: ['a'],
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Study squad'), findsOneWidget);
      expect(find.text('a-a'), findsOneWidget);
      // The name change must not restart the task screen or its stream.
      expect(service.scopes['a']!.cancelled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a blank name is rejected and nothing is saved', (
      tester,
    ) async {
      final service = await openRename(tester);
      await tester.enterText(field, '   ');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text(invalidListNameMessage), findsOneWidget);
      expect(service.renames, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      // The error clears as soon as the name becomes valid, not on the next save.
      await tester.enterText(field, 'Study squad');
      await tester.pumpAndSettle();
      expect(find.text(invalidListNameMessage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('saving locks the field without toggling readOnly', (
      tester,
    ) async {
      final service = await openRename(tester);
      service.actionGate = Completer<void>();
      await tester.enterText(field, 'Study squad');
      await tester.tap(save);
      await tester.pump();
      await tester.pump();
      final editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.readOnly, isFalse);
      expect(editable.focusNode.hasFocus, isFalse);
      expect(service.renames, isEmpty);
      service.actionGate!.complete();
      await tester.pumpAndSettle();
      expect(service.renames, ['a:Study squad']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a failed rename shows the reason and can be retried', (
      tester,
    ) async {
      final service = await openRename(tester);
      service.renameError = StateError('Rename rejected.');
      await tester.enterText(field, 'Study squad');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Rename rejected.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      service.renameError = null;
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(service.renames, ['a:Study squad']);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('losing the group closes the rename dialog without saving', (
      tester,
    ) async {
      final service = await openRename(tester);
      await tester.enterText(field, 'Study squad');
      service.lists.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(service.renames, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('list names are trimmed and limited like the Firestore rules', () {
      expect(isValidListName('Study squad'), isTrue);
      expect(isValidListName('  x  '), isTrue);
      expect(isValidListName(''), isFalse);
      expect(isValidListName('   '), isFalse);
      expect(isValidListName('x' * 100), isTrue);
      expect(isValidListName('x' * 101), isFalse);
    });
  });

  group('member removal', () {
    Future<FakeCollaboration> openMembers(WidgetTester tester) async {
      final service = FakeCollaboration('a')..names['a'] = 'Ari';
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(home: CollaborativeWorkspace(service: service)),
      );
      await tester.pumpAndSettle();
      service.lists.add(const [
        CollaborativeList(
          id: 'a',
          ownerId: 'a',
          name: 'Own group',
          memberIds: ['a', 'typo-uid'],
        ),
      ]);
      await tester.pumpAndSettle();
      await openGroup(tester, 'Own group');
      await tester.tap(find.text('Manage members'));
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets('owners can remove a mistyped UID after confirming', (
      tester,
    ) async {
      final service = await openMembers(tester);
      expect(find.text('Ari (owner)'), findsOneWidget);
      expect(find.text('Unknown account · typo-uid'), findsOneWidget);
      expect(find.text('Current members (2/20)'), findsOneWidget);
      // Only the other member's row can be removed, never the owner's.
      expect(find.byTooltip('Remove member'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove member'));
      await tester.pumpAndSettle();
      expect(find.text('They lose access right away.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(service.membersRemoved, isEmpty);
      expect(find.text('Unknown account · typo-uid'), findsOneWidget);
      expect(find.text('They lose access right away.'), findsNothing);

      await tester.tap(find.byTooltip('Remove member'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(service.membersRemoved, ['a:typo-uid']);
      expect(find.text('Unknown account · typo-uid'), findsNothing);
      expect(find.text('Member removed.'), findsOneWidget);
      expect(find.text('Current members (1/20)'), findsOneWidget);
      expect(find.byTooltip('Remove member'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a failed removal keeps the member and shows the reason', (
      tester,
    ) async {
      final service = await openMembers(tester);
      service.removeError = StateError('Removal rejected.');
      await tester.tap(find.byTooltip('Remove member'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(service.membersRemoved, isEmpty);
      expect(find.text('Removal rejected.'), findsOneWidget);
      expect(find.text('Member removed.'), findsNothing);
      expect(find.text('Unknown account · typo-uid'), findsOneWidget);
      expect(find.text('Current members (2/20)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a full group scrolls in a narrow dialog at large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = FakeCollaboration('a');
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
      service.lists.add([
        CollaborativeList(
          id: 'a',
          ownerId: 'a',
          name: 'Own group',
          memberIds: [
            'a',
            for (var i = 1; i < 20; i++) 'member-account-uid-$i',
          ],
        ),
      ]);
      await tester.pumpAndSettle();
      await selectTab(tester, 'Groups');
      final card = find.widgetWithText(ListTile, 'Own group');
      await tester.scrollUntilVisible(
        card,
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage members'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The last member is reachable and the result stays visible after it.
      final last = find.text('Unknown account · member-account-uid-19');
      await tester.dragUntilVisible(
        last,
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      final row = find.ancestor(of: last, matching: find.byType(Row)).first;
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('Remove member')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(service.membersRemoved, ['a:member-account-uid-19']);
      expect(find.text('Member removed.').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('starting a removal clears the previous result', (
      tester,
    ) async {
      await openMembers(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Account UID'),
        'another-uid',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add member'));
      await tester.pumpAndSettle();
      expect(find.text('Member added.'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove member').first);
      await tester.pumpAndSettle();
      expect(find.text('Member added.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('losing the group closes the dialog mid-confirmation', (
      tester,
    ) async {
      final service = await openMembers(tester);
      await tester.tap(find.byTooltip('Remove member'));
      await tester.pumpAndSettle();
      service.lists.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('They lose access right away.'), findsNothing);
      expect(service.membersRemoved, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
