import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:do_it_now/core/limits.dart';
import 'package:do_it_now/models/task.dart';
import 'package:do_it_now/services/task_repository.dart';
import 'package:do_it_now/screens/task_home_page.dart';
import 'package:do_it_now/theme/app_theme.dart';
import 'package:do_it_now/widgets/system_notice.dart';
import 'package:do_it_now/widgets/task_form_dialog.dart';
import 'package:do_it_now/widgets/task_tile.dart';

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
  final List<Task> deletedTasks = [];
  Object? updateError;

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
    if (updateError != null) throw updateError!;
    updatedTasks.add(task);
    _emitChange();
  }

  @override
  Future<void> deleteTask(Task task) async {
    deletedTasks.add(task);
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

    expect(find.text('QUEST LOG'), findsOneWidget);
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

  testWidgets('clearing a task announces it, then the notice leaves', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: FakeTaskRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Quest cleared'), findsNothing);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Quest cleared: Crud test 1'), findsOneWidget);

    await tester.pump(systemNoticeDuration);
    await tester.pumpAndSettle();
    expect(find.textContaining('Quest cleared'), findsNothing);
  });

  testWidgets('reopening a task is not announced', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: FakeTaskRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Quest cleared'), findsNothing);
  });

  testWidgets('a failed completion takes the announcement back', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeTaskRepository()..updateError = Exception('down');
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Quest cleared'), findsNothing);

    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
  });

  testWidgets('the notice does not disturb an active Undo bar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeTaskRepository()
      .._tasks.add(
        Task(
          title: 'Crud test 3',
          details: '',
          id: 'three',
          createdAt: DateTime(2026, 8, 1),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('Quest cleared: Crud test 3'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('offers Undo before finalizing deletion', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeTaskRepository();
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byIcon(Icons.delete_outline).first,
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Crud test 1'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Crud test 1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(repository.deletedTasks, isEmpty);
  });

  testWidgets('Undo disappears when the deletion commits', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeTaskRepository();
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    expect(repository.deletedTasks, isEmpty);

    await tester.pump(undoDeleteWindow);
    await tester.pumpAndSettle();

    expect(repository.deletedTasks.single.title, 'Crud test 1');
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('clicking outside asks before discarding an edited task', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeTaskRepository();
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsNothing);
    expect(find.byType(TaskFormDialog), findsNothing);

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Half written',
    );
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskFormDialog), findsOneWidget);
    expect(find.text('Half written'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskFormDialog), findsNothing);
    expect(find.text('Half written'), findsNothing);
  });

  testWidgets('Enter in the title creates the task', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: FakeTaskRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Made with Enter',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TaskFormDialog), findsNothing);
    expect(find.text('Made with Enter'), findsOneWidget);
  });

  testWidgets('the task dialog keeps its width while typing', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: FakeTaskRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    final emptyWidth = tester.getSize(find.byType(AlertDialog)).width;
    await tester.enterText(
      find.widgetWithText(TextField, 'Details'),
      'A long description that would otherwise widen the dialog. ' * 4,
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(AlertDialog)).width, emptyWidth);
  });

  testWidgets('Cancel closes an edited task without asking', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: FakeTaskRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Half written',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsNothing);
    expect(find.byType(TaskFormDialog), findsNothing);
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
    expect(find.text('2'), findsOneWidget);

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
      .._tasks[1].isDone = false
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
    await tester.tap(find.text('Sort: Category'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final personalOffset = tester.getCenter(find.text('Crud test 2'));
    final schoolOffset = tester.getCenter(find.text('Crud test 1'));
    final othersOffset = tester.getCenter(find.text('Other task'));
    expect(personalOffset.dy, lessThan(schoolOffset.dy));
    expect(schoolOffset.dy, lessThan(othersOffset.dy));
  });

  testWidgets('open tasks stay above completed ones under every sort', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeTaskRepository().._tasks[0].isDone = true;
    repository._tasks[1].isDone = false;
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    for (final option in ['Priority', 'Due date', 'Category', 'Date added']) {
      await tester.tap(find.byType(DropdownButton<TaskSortOption>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort: $option').last);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Crud test 2')).dy,
        lessThan(tester.getCenter(find.text('Crud test 1')).dy),
        reason: option,
      );
    }
  });

  test('a task is overdue only after its deadline and while open', () {
    final dated = Task(
      title: 'Due',
      details: '',
      dueDate: DateTime(2026, 3, 9),
    );
    expect(dated.isOverdueAt(DateTime(2026, 3, 9, 23, 59)), isFalse);
    expect(dated.isOverdueAt(DateTime(2026, 3, 10)), isTrue);

    dated.dueTime = const TimeOfDay(hour: 14, minute: 30);
    expect(dated.isOverdueAt(DateTime(2026, 3, 9, 14, 29)), isFalse);
    expect(dated.isOverdueAt(DateTime(2026, 3, 9, 14, 30)), isTrue);

    dated.isDone = true;
    expect(dated.isOverdueAt(DateTime(2027)), isFalse);

    final timeOnly = Task(
      title: 'No date',
      details: '',
      dueTime: const TimeOfDay(hour: 1, minute: 0),
    );
    expect(timeOnly.isOverdueAt(DateTime(2027)), isFalse);
  });

  testWidgets('an overdue task is flagged', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeTaskRepository()
      .._tasks[0].dueDate = DateTime(2020)
      .._tasks[1].dueDate = DateTime(2020);
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: repository)),
    );
    await tester.pumpAndSettle();
    // Crud test 2 is also past due, but it is already complete.
    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('Clear filters brings hidden tasks back', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: FakeTaskRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear filters'), findsNothing);

    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medium').last);
    await tester.pumpAndSettle();
    expect(find.text('Crud test 1'), findsNothing);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Crud test 1'), findsOneWidget);
    expect(find.text('Crud test 2'), findsOneWidget);
  });

  testWidgets('a failed save does not show raw error text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeTaskRepository()
      ..updateError = Exception(
        '[cloud_firestore/unavailable] internal detail',
      );
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('internal detail'), findsNothing);
    expect(
      find.text('Could not complete the request. Try again.'),
      findsOneWidget,
    );
  });

  test('every button type shows a ring when it has keyboard focus', () {
    final theme = AppTheme.dark;
    final focused = {WidgetState.focused};
    for (final style in [
      theme.filledButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.textButtonTheme.style,
      theme.iconButtonTheme.style,
      AppButtonStyles.secondary,
    ]) {
      expect(style!.side!.resolve(focused)?.width, 2);
    }
    expect(
      theme.textButtonTheme.style!.side!.resolve(const {}),
      isNull,
      reason: 'a text button has no border unless it is focused',
    );
    expect(
      theme.outlinedButtonTheme.style!.side!.resolve(const {})?.color,
      AppColors.controlBorder,
    );
  });

  testWidgets('the phone layout keeps the first task near the top', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: TaskHomePage(
          repository: FakeTaskRepository(),
          appBarBottom: const TabBar(
            controller: null,
            tabs: [
              Tab(text: 'Personal'),
              Tab(text: 'Groups'),
            ],
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: const Size(375, 812)),
          child: DefaultTabController(length: 2, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The wide test font wraps the filters onto a third row. With the app's
    // font they take two, which puts the first task in the top half.
    expect(tester.getTopLeft(find.byType(TaskTile).first).dy, lessThan(520));
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter controls fit a narrow display at large text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(320, 760),
            textScaler: const TextScaler.linear(2),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: TaskHomePage(repository: FakeTaskRepository()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButton<String>), findsNWidgets(2));

    // A control that had to shrink still opens and selects.
    final sort = find.byType(DropdownButton<TaskSortOption>);
    await tester.ensureVisible(sort);
    await tester.pumpAndSettle();
    await tester.tap(sort);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort: Category').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<DropdownButton<TaskSortOption>>(sort).value,
      TaskSortOption.tag,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter controls keep their natural width on a wide display', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TaskHomePage(repository: FakeTaskRepository())),
    );
    await tester.pumpAndSettle();

    final sort = find.byType(DropdownButton<TaskSortOption>);
    final filters = find.byType(DropdownButton<String>);
    expect(tester.getSize(sort).width, lessThan(400));
    expect(tester.getTopLeft(filters.first).dy, tester.getTopLeft(sort).dy);
    expect(tester.getTopLeft(filters.last).dy, tester.getTopLeft(sort).dy);
  });

  testWidgets('reflows the dashboard and task form on a narrow display', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(320, 760),
            textScaler: const TextScaler.linear(2),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: TaskHomePage(repository: FakeTaskRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Due date'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
