import 'package:firebase_auth/firebase_auth.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/task_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/stat.dart';
import '../widgets/status_panel.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/task_tile.dart';
import 'profile_screen.dart';

enum TaskSortOption { dateAdded, dueDate, priority, tag }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({
    super.key,
    this.repository,
    this.listControls,
    this.listName = 'Personal',
    this.onAccessLost,
  });

  final TaskRepository? repository;
  final Widget? listControls;
  final String listName;
  final VoidCallback? onAccessLost;

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  late final TaskRepository _repository =
      widget.repository ?? FirestoreTaskRepository();
  late final Stream<List<Task>> _taskStream = _repository.watchTasks();
  final Set<DialogRoute<dynamic>> _dialogs = {};
  bool _reportedAccessLoss = false;
  TaskSortOption _sortOption = TaskSortOption.dateAdded;
  TaskPriority? _priorityFilter;
  TaskCategory? _categoryFilter;
  final Set<String> _hiddenTaskIds = {};
  final Map<String, Timer> _pendingDeletionTimers = {};
  final Map<String, Task> _pendingDeletions = {};
  ScaffoldMessengerState? _messenger;
  bool _disposing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  Future<void> _commitDeletion(String taskId) async {
    _pendingDeletionTimers.remove(taskId)?.cancel();
    final task = _pendingDeletions.remove(taskId);
    if (task == null) return;
    try {
      await _repository.deleteTask(task);
    } catch (error) {
      if (mounted && !_disposing) {
        setState(() => _hiddenTaskIds.remove(taskId));
        _showError(error);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_messenger?.mounted == true) {
            _messenger!.showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not complete a deletion in the previous list. Reopen it to retry.',
                ),
              ),
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _disposing = true;
    // Leaving a list ends Undo and commits each deletion to its original scope.
    // The repository also rejects writes if the authenticated account changed.
    if (_pendingDeletionTimers.isNotEmpty || _hiddenTaskIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_messenger?.mounted == true) _messenger!.hideCurrentSnackBar();
      });
    }
    for (final taskId in _pendingDeletions.keys.toList()) {
      unawaited(_commitDeletion(taskId));
    }
    for (final route in _dialogs.toList()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  Future<T?> _showScopedDialog<T>(WidgetBuilder builder) async {
    final route = DialogRoute<T>(context: context, builder: builder);
    _dialogs.add(route);
    try {
      return await Navigator.of(context).push(route);
    } finally {
      _dialogs.remove(route);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not save task: $error')));
  }

  Future<void> _openTaskForm({Task? task}) async {
    final repository = _repository;
    final result = await _showScopedDialog<Task>(
      (_) => TaskFormDialog(task: task),
    );
    if (!mounted || result == null) return;
    try {
      if (task == null) {
        result.createdAt ??= DateTime.now();
        await repository.createTask(result);
      } else {
        task
          ..title = result.title
          ..details = result.details
          ..dueDate = result.dueDate
          ..dueTime = result.dueTime
          ..priority = result.priority
          ..category = result.category;
        await repository.updateTask(task);
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await _showScopedDialog<bool>(
      (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          '"${task.title}" will be removed from this list. '
          'Undo is available for five seconds while you stay in this list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final taskId = task.id;
    if (taskId == null) {
      _showError(StateError('Cannot delete a task without an ID.'));
      return;
    }

    setState(() => _hiddenTaskIds.add(taskId));
    _pendingDeletions[taskId] = task;
    final timer = Timer(
      const Duration(seconds: 5),
      () => _commitDeletion(taskId),
    );
    _pendingDeletionTimers[taskId] = timer;

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${task.title}" deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            timer.cancel();
            _pendingDeletionTimers.remove(taskId);
            _pendingDeletions.remove(taskId);
            if (mounted) setState(() => _hiddenTaskIds.remove(taskId));
          },
        ),
      ),
    );
  }

  List<Task> _prepareTasks(List<Task> source) {
    final tasks = source
        .where((task) => task.id == null || !_hiddenTaskIds.contains(task.id))
        .where(
          (task) => _priorityFilter == null || task.priority == _priorityFilter,
        )
        .where(
          (task) => _categoryFilter == null || task.category == _categoryFilter,
        )
        .toList();
    tasks.sort((first, second) {
      switch (_sortOption) {
        case TaskSortOption.dateAdded:
          return (second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              );
        case TaskSortOption.dueDate:
          return _compareNullableDates(first.dueDate, second.dueDate);
        case TaskSortOption.priority:
          return second.priority.index.compareTo(first.priority.index);
        case TaskSortOption.tag:
          return _tagOrder(first.category)
              .compareTo(_tagOrder(second.category));
      }
    });
    return tasks;
  }

  int _tagOrder(TaskCategory category) => switch (category) {
    TaskCategory.personal => 0,
    TaskCategory.school => 1,
    TaskCategory.others => 2,
  };

  int _compareNullableDates(DateTime? first, DateTime? second) {
    if (first == null && second == null) return 0;
    if (first == null) return 1;
    if (second == null) return -1;
    return first.compareTo(second);
  }

  String _label(Enum value) =>
      value.name[0].toUpperCase() + value.name.substring(1);

  String _sortLabel(TaskSortOption value) => switch (value) {
    TaskSortOption.dateAdded => 'Date added',
    TaskSortOption.dueDate => 'Due date',
    TaskSortOption.priority => 'Priority',
    TaskSortOption.tag => 'Category',
  };

  String _userInitial() {
    try {
      final name = FirebaseAuth.instance.currentUser?.displayName;
      return (name?.isNotEmpty == true ? name![0] : '?').toUpperCase();
    } on FirebaseException {
      return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DO IT NOW!'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            icon: CircleAvatar(
              radius: 14,
              child: Text(_userInitial(), style: const TextStyle(fontSize: 12)),
            ),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () => _openTaskForm(),
            icon: const Icon(Icons.add_task),
            tooltip: 'Add task',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: MediaQuery.sizeOf(context).width < 700
          ? FloatingActionButton.extended(
              onPressed: () => _openTaskForm(),
              icon: const Icon(Icons.add),
              label: const Text('New task'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          if (widget.listControls != null) widget.listControls!,
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _taskStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  if (!_reportedAccessLoss &&
                      widget.onAccessLost != null &&
                      snapshot.error is FirebaseException &&
                      (snapshot.error as FirebaseException).code ==
                          'permission-denied') {
                    _reportedAccessLoss = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) widget.onAccessLost?.call();
                    });
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.highPriority,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load tasks: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = _prepareTasks(snapshot.data!);
                final allTasks = snapshot.data!
                    .where(
                      (task) =>
                          task.id == null || !_hiddenTaskIds.contains(task.id),
                    )
                    .toList();
                final total = allTasks.length;
                final completedCount = allTasks
                    .where((task) => task.isDone)
                    .length;
                final completionRatio = allTasks.isEmpty
                    ? 0.0
                    : completedCount / allTasks.length;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 700;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 16 : 24,
                            compact ? 16 : 24,
                            compact ? 16 : 24,
                            compact ? 96 : 32,
                          ),
                          children: [
                            StatusPanel(
                              padding: 20,
                              child: LayoutBuilder(
                                builder: (context, panelConstraints) {
                                  final horizontal =
                                      panelConstraints.maxWidth >= 680;
                                  final metrics = Row(
                                    children: [
                                      Stat(label: 'Total', value: '$total'),
                                      const SizedBox(width: 16),
                                      Stat(
                                        label: 'Done',
                                        value: '$completedCount',
                                      ),
                                      const SizedBox(width: 16),
                                      Stat(
                                        label: 'Open',
                                        value: '${total - completedCount}',
                                      ),
                                    ],
                                  );
                                  final title = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 10,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          const StatusEyebrow(
                                            'Mission control',
                                          ),
                                          Text(
                                            widget.listName,
                                            style: const TextStyle(
                                              color: AppColors.secondaryText,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Task completion',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontFamily: 'Exo 2',
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Track your task completion.',
                                        style: TextStyle(
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (horizontal)
                                        Row(
                                          children: [
                                            Expanded(child: title),
                                            const SizedBox(width: 24),
                                            SizedBox(
                                              width: 340,
                                              child: metrics,
                                            ),
                                          ],
                                        )
                                      else ...[
                                        title,
                                        const SizedBox(height: 16),
                                        metrics,
                                      ],
                                      const SizedBox(height: 16),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: completionRatio,
                                          minHeight: 8,
                                          semanticsLabel: 'Task completion',
                                          semanticsValue:
                                              '${(completionRatio * 100).round()}',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${(completionRatio * 100).round()}% complete',
                                        style: const TextStyle(
                                          color: AppColors.secondaryText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Tasks',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontFamily: 'Exo 2',
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  if (!compact)
                                    FilledButton.icon(
                                      onPressed: () => _openTaskForm(),
                                      icon: const Icon(Icons.add),
                                      label: const Text('New task'),
                                    ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _controlShell(
                                  icon: Icons.sort,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<TaskSortOption>(
                                      value: _sortOption,
                                      style: const TextStyle(
                                        color: AppColors.primaryText,
                                      ),
                                      dropdownColor: AppColors.surface,
                                      iconEnabledColor: AppColors.secondaryText,
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _sortOption = value);
                                        }
                                      },
                                      items: TaskSortOption.values
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(
                                                'Sort: ${_sortLabel(value)}',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                                _controlShell(
                                  icon: Icons.sell_outlined,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _categoryFilter?.name ?? 'all',
                                      style: const TextStyle(
                                        color: AppColors.primaryText,
                                      ),
                                      dropdownColor: AppColors.surface,
                                      iconEnabledColor: AppColors.secondaryText,
                                      onChanged: (value) => setState(
                                        () => _categoryFilter =
                                            value == null || value == 'all'
                                            ? null
                                            : TaskCategory.values.byName(value),
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: 'all',
                                          child: Text('All categories'),
                                        ),
                                        ...TaskCategory.values.map(
                                          (value) => DropdownMenuItem(
                                            value: value.name,
                                            child: Text(_label(value)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _controlShell(
                                  icon: Icons.flag_outlined,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _priorityFilter?.name ?? 'all',
                                      style: const TextStyle(
                                        color: AppColors.primaryText,
                                      ),
                                      dropdownColor: AppColors.surface,
                                      iconEnabledColor: AppColors.secondaryText,
                                      onChanged: (value) => setState(
                                        () => _priorityFilter =
                                            value == null || value == 'all'
                                            ? null
                                            : TaskPriority.values.byName(value),
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: 'all',
                                          child: Text('All priorities'),
                                        ),
                                        ...TaskPriority.values.map(
                                          (value) => DropdownMenuItem(
                                            value: value.name,
                                            child: Text(_label(value)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (tasks.isEmpty)
                              EmptyState(filtered: allTasks.isNotEmpty)
                            else
                              ...tasks.map(
                                (task) => TaskTile(
                                  task: task,
                                  onChanged: (value) async {
                                    task.isDone = value ?? false;
                                    try {
                                      await _repository.updateTask(task);
                                    } catch (error) {
                                      _showError(error);
                                    }
                                  },
                                  onEdit: () => _openTaskForm(task: task),
                                  onDelete: () => _deleteTask(task),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlShell({required IconData icon, required Widget child}) =>
      Container(
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(
          color: AppColors.raisedSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.controlBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 18, color: AppColors.cyan),
            ),
            const SizedBox(width: 6),
            child,
          ],
        ),
      );
}
