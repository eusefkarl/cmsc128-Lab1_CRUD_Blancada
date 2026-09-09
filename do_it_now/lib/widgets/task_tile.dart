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
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(task.priority);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: task.isDone ? const Color(0xFF00E5FF) : priorityColor,
              width: 6,
            ),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          leading: Checkbox(value: task.isDone, onChanged: onChanged),
          title: Text(
            task.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              decoration: task.isDone ? TextDecoration.lineThrough : null,
              color: task.isDone
                  ? const Color(0xFF5C7580)
                  : const Color(0xFFF0F6F8),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.details.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  task.details,
                  style: TextStyle(color: const Color(0xFF5C7580)),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Badge(
                    label: _label(task.priority),
                    color: priorityColor,
                    icon: Icons.flag_outlined,
                  ),
                  _Badge(
                    label: _label(task.category),
                    color: const Color(0xFF3D6B8A),
                    icon: Icons.sell_outlined,
                  ),
                  if (task.dueDate != null)
                    _Badge(
                      label: 'Due ${task.dueDate!.month}/${task.dueDate!.day}',
                      color: const Color(0xFF5B6F7B),
                      icon: Icons.calendar_today_outlined,
                    ),
                  if (task.dueTime != null)
                    _Badge(
                      label: task.dueTime!.format(context),
                      color: const Color(0xFF5B6F7B),
                      icon: Icons.schedule_outlined,
                    ),
                ],
              ),
            ],
          ),
          trailing: Wrap(
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
      ),
    );
  }

  Color _priorityColor(TaskPriority priority) => switch (priority) {
    TaskPriority.high => const Color(0xFFFF2D55),
    TaskPriority.medium => const Color(0xFFFFB100),
    TaskPriority.low => const Color(0xFF39FF8F),
  };

  String _label(Enum value) =>
      value.name[0].toUpperCase() + value.name.substring(1);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2B3A),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
