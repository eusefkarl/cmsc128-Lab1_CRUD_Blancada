import 'package:flutter/material.dart';

enum TaskPriority { low, medium, high }

enum TaskCategory { school, personal, others }

class Task {
  Task({
    required this.title,
    required this.details,
    this.dueDate,
    this.dueTime,
    this.priority = TaskPriority.medium,
    this.category = TaskCategory.others,
    this.isDone = false,
  });

  String title;
  String details;
  DateTime? dueDate;
  TimeOfDay? dueTime;
  TaskPriority priority;
  TaskCategory category;
  bool isDone;
}
