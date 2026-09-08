import 'package:flutter/material.dart';

import 'dart:async';

import '../models/task.dart';
import '../services/task_repository.dart';
import '../widgets/empty_state.dart';
import '../widgets/stat.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/task_tile.dart';

enum TaskSortOption { dateAdded, dueDate, priority, tag }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key, this.repository});

  final TaskRepository? repository;

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  late final TaskRepository _repository =
      widget.repository ?? FirestoreTaskRepository();
  TaskSortOption _sortOption = TaskSortOption.dateAdded;
  TaskPriority? _priorityFilter;
  TaskCategory? _categoryFilter;
  final Set<String> _hiddenTaskIds = {};
  final Map<String, Timer> _pendingDeletionTimers = {};

  @override
  void dispose() {
    for (final timer in _pendingDeletionTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not save task: $error')));
  }

  Future<void> _openTaskForm({Task? task}) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (_) => TaskFormDialog(task: task),
    );
    if (result == null) return;
    try {
      if (task == null) {
        result.createdAt ??= DateTime.now();
        await _repository.createTask(result);
      } else {
        task
          ..title = result.title
          ..details = result.details
          ..dueDate = result.dueDate
          ..dueTime = result.dueTime
          ..priority = result.priority
          ..category = result.category;
        await _repository.updateTask(task);
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed from this list.'),
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
    if (confirmed != true) return;
    final taskId = task.id;
    if (taskId == null) {
      _showError(StateError('Cannot delete a task without an ID.'));
      return;
    }

    setState(() => _hiddenTaskIds.add(taskId));
    final timer = Timer(const Duration(seconds: 5), () async {
      try {
        await _repository.deleteTask(task);
        _pendingDeletionTimers.remove(taskId);
      } catch (error) {
        _pendingDeletionTimers.remove(taskId);
        if (mounted) {
          setState(() => _hiddenTaskIds.remove(taskId));
          _showError(error);
        }
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Desk'),
        actions: [
          IconButton(
            onPressed: () => _openTaskForm(),
            icon: const Icon(Icons.add_task),
            tooltip: 'Add task',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: StreamBuilder<List<Task>>(
        stream: _repository.watchTasks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load tasks: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = _prepareTasks(snapshot.data!);
          final allTasks = snapshot.data!
              .where(
                (task) => task.id == null || !_hiddenTaskIds.contains(task.id),
              )
              .toList();
          final completedCount = allTasks.where((task) => task.isDone).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            children: [
              Text(
                'Your workspace',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Keep the next step visible and moving.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Stat(label: 'Total', value: '${allTasks.length}'),
                  const SizedBox(width: 12),
                  Stat(label: 'Done', value: '$completedCount'),
                  const SizedBox(width: 12),
                  Stat(
                    label: 'Open',
                    value: '${allTasks.length - completedCount}',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  DropdownButton<TaskSortOption>(
                    value: _sortOption,
                    onChanged: (value) {
                      if (value != null) setState(() => _sortOption = value);
                    },
                    items: TaskSortOption.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('Sort: ${_label(value)}'),
                          ),
                        )
                        .toList(),
                  ),
                  DropdownButton<String>(
                    value: _categoryFilter?.name ?? 'all',
                    hint: const Text('Tag'),
                    onChanged: (value) => setState(
                      () => _categoryFilter = value == null || value == 'all'
                          ? null
                          : TaskCategory.values.byName(value),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All tags'),
                      ),
                      ...TaskCategory.values.map(
                        (value) => DropdownMenuItem(
                          value: value.name,
                          child: Text(_label(value)),
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<String>(
                    value: _priorityFilter?.name ?? 'all',
                    hint: const Text('Priority'),
                    onChanged: (value) => setState(
                      () => _priorityFilter = value == null || value == 'all'
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
                ],
              ),
              const SizedBox(height: 20),
              if (tasks.isEmpty)
                const EmptyState()
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
          );
        },
      ),
    );
  }
}
