import '../models/task.dart';

/// Reaching the next level costs this much XP times the current level.
const int xpLevelStep = 100;

/// The XP a task earns while it is completed.
int xpForTask(Task task) => switch (task.priority) {
  TaskPriority.low => 10,
  TaskPriority.medium => 20,
  TaskPriority.high => 30,
};

/// A list's level, worked out from its tasks rather than stored, so reopening
/// or deleting a completed task takes its XP back.
class Progression {
  const Progression._({
    required this.level,
    required this.xpIntoLevel,
    required this.xpToNextLevel,
  });

  factory Progression.fromTasks(Iterable<Task> tasks) => Progression.fromXp(
    tasks
        .where((task) => task.isDone)
        .fold(0, (total, task) => total + xpForTask(task)),
  );

  factory Progression.fromXp(int xp) {
    var level = 1;
    var remaining = xp;
    while (remaining >= level * xpLevelStep) {
      remaining -= level * xpLevelStep;
      level++;
    }
    return Progression._(
      level: level,
      xpIntoLevel: remaining,
      xpToNextLevel: level * xpLevelStep,
    );
  }

  final int level;
  final int xpIntoLevel;
  final int xpToNextLevel;

  double get levelRatio => xpIntoLevel / xpToNextLevel;
}
