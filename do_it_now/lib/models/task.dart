import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { low, medium, high }

enum TaskCategory { school, personal, others }

class Task {
  Task({
    this.id,
    this.ownerId,
    required this.title,
    required this.details,
    this.createdAt,
    this.dueDate,
    this.dueTime,
    this.priority = TaskPriority.medium,
    this.category = TaskCategory.others,
    this.isDone = false,
  });

  String? id;
  String? ownerId;
  String title;
  String details;
  DateTime? createdAt;
  DateTime? dueDate;
  TimeOfDay? dueTime;
  TaskPriority priority;
  TaskCategory category;
  bool isDone;

  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? <String, dynamic>{};
    final dueDate = data['dueDate'];
    final dueTime = data['dueTime'];

    return Task(
      id: document.id,
      ownerId: data['ownerId'] as String?,
      title: data['title'] as String? ?? '',
      details: data['details'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      dueDate: dueDate is Timestamp ? dueDate.toDate() : null,
      dueTime: dueTime is int
          ? TimeOfDay(hour: dueTime ~/ 60, minute: dueTime % 60)
          : null,
      priority: TaskPriority.values.firstWhere(
        (value) => value.name == data['priority'],
        orElse: () => TaskPriority.medium,
      ),
      category: TaskCategory.values.firstWhere(
        (value) => value.name == data['category'],
        orElse: () => TaskCategory.others,
      ),
      isDone: data['isDone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'ownerId': ownerId,
    'title': title,
    'details': details,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
    'dueTime': dueTime == null ? null : dueTime!.hour * 60 + dueTime!.minute,
    'priority': priority.name,
    'category': category.name,
    'isDone': isDone,
  };
}
