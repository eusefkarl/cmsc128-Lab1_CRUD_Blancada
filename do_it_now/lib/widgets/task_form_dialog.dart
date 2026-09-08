import 'package:flutter/material.dart';

import '../models/task.dart';

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({super.key, this.task});
  final Task? task;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  late TaskPriority _priority;
  late TaskCategory _category;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title);
    _detailsController = TextEditingController(text: widget.task?.details);
    _dueDate = widget.task?.dueDate;
    _dueTime = widget.task?.dueTime;
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _category = widget.task?.category ?? TaskCategory.others;
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
        dueDate: _dueDate,
        dueTime: _dueTime,
        priority: _priority,
        category: _category,
        isDone: widget.task?.isDone ?? false,
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null) setState(() => _dueDate = selectedDate);
  }

  Future<void> _selectDueTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (selectedTime != null) setState(() => _dueTime = selectedTime);
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDueDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _dueDate == null ? 'Due date' : _formatDate(_dueDate!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDueTime,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(_dueTime?.format(context) ?? 'Due time'),
                ),
              ),
            ],
          ),
          DropdownButtonFormField<TaskPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: TaskPriority.values
                .map(
                  (priority) => DropdownMenuItem(
                    value: priority,
                    child: Text(
                      priority.name[0].toUpperCase() +
                          priority.name.substring(1),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _priority = value);
            },
          ),
          DropdownButtonFormField<TaskCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: TaskCategory.values
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(
                      category.name[0].toUpperCase() +
                          category.name.substring(1),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
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
