import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';

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
    final details = _taskDetails(context, priorityColor);
    final actions = Wrap(
      spacing: 4,
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
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: task.isDone ? AppColors.cyan : priorityColor,
              width: 3,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final checkbox = SizedBox(
              width: 48,
              height: 48,
              child: Checkbox(
                value: task.isDone,
                onChanged: onChanged,
                semanticLabel:
                    '${task.isDone ? 'Mark incomplete' : 'Complete'} ${task.title}',
              ),
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            checkbox,
                            const SizedBox(width: 8),
                            Expanded(child: details),
                          ],
                        ),
                        Align(alignment: Alignment.centerRight, child: actions),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        checkbox,
                        const SizedBox(width: 8),
                        Expanded(child: details),
                        actions,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _taskDetails(BuildContext context, Color priorityColor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Text(
        task.title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          decoration: task.isDone ? TextDecoration.lineThrough : null,
          color: task.isDone ? AppColors.secondaryText : AppColors.primaryText,
        ),
      ),
      if (task.details.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          task.details,
          style: const TextStyle(color: AppColors.secondaryText),
        ),
      ],
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Badge(
            label: _label(task.priority),
            color: priorityColor,
            icon: Icons.flag_outlined,
          ),
          _Badge(
            label: _label(task.category),
            color: AppColors.secondaryText,
            icon: Icons.sell_outlined,
          ),
          if (task.dueDate != null)
            _Badge(
              label:
                  'Due ${MaterialLocalizations.of(context).formatMediumDate(task.dueDate!)}',
              color: AppColors.secondaryText,
              icon: Icons.calendar_today_outlined,
            ),
          if (task.dueTime != null)
            _Badge(
              label: task.dueTime!.format(context),
              color: AppColors.secondaryText,
              icon: Icons.schedule_outlined,
            ),
        ],
      ),
    ],
  );

  Color _priorityColor(TaskPriority priority) => switch (priority) {
    TaskPriority.high => AppColors.highPriority,
    TaskPriority.medium => AppColors.mediumPriority,
    TaskPriority.low => AppColors.lowPriority,
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
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.raisedSurface,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 15, color: color)),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
