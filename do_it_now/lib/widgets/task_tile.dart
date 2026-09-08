import 'package:flutter/material.dart';

import '../models/task.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.details),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (task.dueDate != null)
                Text(
                  'Due ${task.dueDate!.month}/${task.dueDate!.day}/${task.dueDate!.year}',
                ),
              if (task.dueTime != null) Text(task.dueTime!.format(context)),
              Text(_label(task.priority)),
              Text(_label(task.category)),
            ],
          ),
        ],
      ),
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

  String _label(Enum value) =>
      value.name[0].toUpperCase() + value.name.substring(1);
}
