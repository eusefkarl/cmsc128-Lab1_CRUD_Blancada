import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Desk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B87),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F8),
        useMaterial3: true,
      ),
      home: const TaskHomePage(),
    );
  }
}

class Task {
  Task({required this.title, required this.details, this.isDone = false});

  String title;
  String details;
  bool isDone;
}

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  final List<Task> _tasks = [
    Task(
      title: 'Map the first user flow',
      details: 'Sketch the create, edit, and delete states.',
    ),
    Task(
      title: 'Review the data model',
      details: 'Check required fields before connecting a backend.',
      isDone: true,
    ),
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
              _Stat(label: 'Total', value: '${_tasks.length}'),
              const SizedBox(width: 12),
              _Stat(label: 'Done', value: '$completedCount'),
              const SizedBox(width: 12),
              _Stat(label: 'Open', value: '${_tasks.length - completedCount}'),
            ],
          ),
          const SizedBox(height: 28),
          if (_tasks.isEmpty)
            const _EmptyState()
          else
            ..._tasks.map(
              (task) => _TaskTile(
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    ),
  );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });
  final Task task;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: Checkbox(value: task.isDone, onChanged: onChanged),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.isDone ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(task.details),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit task',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete task',
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('No tasks yet'),
          const Text(
            'Create one to get started.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({super.key, this.task});
  final Task? task;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title);
    _detailsController = TextEditingController(text: widget.task?.details);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      Task(
        title: _titleController.text.trim(),
        details: _detailsController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit task' : 'New task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _detailsController,
            decoration: const InputDecoration(labelText: 'Details'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
