import 'package:flutter/material.dart';

import '../models/task.dart';
import '../widgets/empty_state.dart';
import '../widgets/stat.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/task_tile.dart';

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  final List<Task> _tasks = [
    Task(title: 'Crud test 1', details: 'filler text.'),
    Task(title: 'Crud test 2', details: 'filler text.', isDone: true),
  ];

  Future<void> _openTaskForm({Task? task}) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (_) => TaskFormDialog(task: task),
    );
    if (result == null) return;
    setState(() {
      if (task == null) {
        _tasks.add(result);
      } else {
        task.title = result.title;
        task.details = result.details;
        task.dueDate = result.dueDate;
        task.dueTime = result.dueTime;
        task.priority = result.priority;
        task.category = result.category;
      }
    });
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
    if (confirmed == true && mounted) setState(() => _tasks.remove(task));
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _tasks.where((task) => task.isDone).length;
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
      body: ListView(
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
              Stat(label: 'Total', value: '${_tasks.length}'),
              const SizedBox(width: 12),
              Stat(label: 'Done', value: '$completedCount'),
              const SizedBox(width: 12),
              Stat(label: 'Open', value: '${_tasks.length - completedCount}'),
            ],
          ),
          const SizedBox(height: 28),
          if (_tasks.isEmpty)
            const EmptyState()
          else
            ..._tasks.map(
              (task) => TaskTile(
                task: task,
                onChanged: (value) =>
                    setState(() => task.isDone = value ?? false),
                onEdit: () => _openTaskForm(task: task),
                onDelete: () => _deleteTask(task),
              ),
            ),
        ],
      ),
    );
  }
}
