import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:do_it_now/models/task.dart';
import 'package:do_it_now/services/task_repository.dart';
import 'package:do_it_now/screens/task_home_page.dart';

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository()
    : _tasks = [
        Task(
          title: 'Crud test 1',
          details: 'filler text.',
          id: 'one',
          createdAt: DateTime(2026, 9, 2),
          priority: TaskPriority.high,
          category: TaskCategory.school,
        ),
        Task(
          title: 'Crud test 2',
          details: 'filler text.',
          isDone: true,
          id: 'two',
          createdAt: DateTime(2026, 9, 1),
          priority: TaskPriority.low,
          category: TaskCategory.personal,
        ),
      ];

  final List<Task> _tasks;
  final StreamController<List<Task>> _changes =
      StreamController<List<Task>>.broadcast();
  final List<Task> updatedTasks = [];

  @override
  Stream<List<Task>> watchTasks() async* {
    yield List.of(_tasks);
    yield* _changes.stream;
  }

  void _emitChange() => _changes.add(List.of(_tasks));

  @override
  Future<void> createTask(Task task) async {
    task.id = 'created';
    _tasks.add(task);
    _emitChange();
  }

  @override
  Future<void> updateTask(Task task) async {
    updatedTasks.add(task);
    _emitChange();
  }

  @override
  Future<void> deleteTask(Task task) async {
    _tasks.remove(task);
    _emitChange();
  }
}

void main() {
  test('serializes all task fields for Firestore', () {
    final task = Task(
      id: 'task-id',
      title: 'Study',
      details: 'Review notes',
      createdAt: DateTime(2026, 9, 1),
      dueDate: DateTime(2026, 9, 10),
      dueTime: const TimeOfDay(hour: 14, minute: 30),
      priority: TaskPriority.high,
      category: TaskCategory.school,
      isDone: true,
    );

    final data = task.toFirestore();

    expect(data['title'], 'Study');
    expect(data['details'], 'Review notes');
    expect(data['createdAt'].toDate(), DateTime(2026, 9, 1));
    expect(data['dueDate'].toDate(), DateTime(2026, 9, 10));
    expect(data['dueTime'], 870);
    expect(data['priority'], 'high');
    expect(data['category'], 'school');
    expect(data['isDone'], isTrue);
  });

  testWidgets('creates, edits, and confirms task deletion', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: FakeTaskRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task Desk'), findsOneWidget);
    expect(find.text('Crud test 1'), findsOneWidget);

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Ship CRUD flow',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Details'),
      'Connect the form to the list.',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Ship CRUD flow'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Ship edited CRUD flow',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Details'),
      'Updated task details.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Ship edited CRUD flow'), findsOneWidget);
    expect(find.text('Updated task details.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('Delete task?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Ship edited CRUD flow'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Ship edited CRUD flow'), findsNothing);
  });

  testWidgets('marks a task done and sends the update to the repository', (
    WidgetTester tester,
  ) async {
    final repository = FakeTaskRepository();
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(repository.updatedTasks.single.isDone, isTrue);
    expect(find.text('Crud test 1'), findsOneWidget);
  });

  testWidgets('offers Undo before finalizing deletion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: FakeTaskRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Crud test 1'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Crud test 1'), findsOneWidget);
  });

  testWidgets('filters tasks by tag and priority', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: FakeTaskRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('School').last);
    await tester.pumpAndSettle();
    expect(find.text('Crud test 1'), findsOneWidget);
    expect(find.text('Crud test 2'), findsNothing);

    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('High').last);
    await tester.pumpAndSettle();
    expect(find.text('Crud test 1'), findsOneWidget);
  });

  testWidgets('sorts tags as personal, school, then others', (
    WidgetTester tester,
  ) async {
    final repository = FakeTaskRepository()
      .._tasks.add(
        Task(
          title: 'Other task',
          details: 'Other details',
          id: 'three',
          category: TaskCategory.others,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<TaskSortOption>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort: Tag'));
    await tester.pumpAndSettle();

    final personalOffset = tester.getCenter(find.text('Crud test 2'));
    final schoolOffset = tester.getCenter(find.text('Crud test 1'));
    final othersOffset = tester.getCenter(find.text('Other task'));
    expect(personalOffset.dy, lessThan(schoolOffset.dy));
    expect(schoolOffset.dy, lessThan(othersOffset.dy));
  });
}
