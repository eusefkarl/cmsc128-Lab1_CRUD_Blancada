import 'package:flutter/material.dart';

import '../models/task.dart';
import 'status_panel.dart';

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
  bool _titleError = false;

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
    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = true);
      return;
    }
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

  String _formatDate(BuildContext context, DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 24, 16),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusEyebrow('Mission control'),
          const SizedBox(height: 6),
          Text(isEditing ? 'Edit task' : 'New task'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (value) {
                  if (_titleError && value.trim().isNotEmpty) {
                    setState(() => _titleError = false);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Title',
                  helperText: 'Required',
                  errorText: _titleError ? 'Enter a task title.' : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _detailsController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final dateButton = OutlinedButton.icon(
                    onPressed: _selectDueDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _dueDate == null
                          ? 'Due date'
                          : _formatDate(context, _dueDate!),
                    ),
                  );
                  final timeButton = OutlinedButton.icon(
                    onPressed: _selectDueTime,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(_dueTime?.format(context) ?? 'Due time'),
                  );
                  if (MediaQuery.sizeOf(context).width < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        dateButton,
                        const SizedBox(height: 8),
                        timeButton,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: dateButton),
                      const SizedBox(width: 12),
                      Expanded(child: timeButton),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                isExpanded: true,
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
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskCategory>(
                initialValue: _category,
                isExpanded: true,
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
        ),
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
