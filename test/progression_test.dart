import 'package:flutter_test/flutter_test.dart';

import 'package:do_it_now/core/progression.dart';
import 'package:do_it_now/models/task.dart';

Task _task(TaskPriority priority, {bool isDone = true}) =>
    Task(title: 'Quest', details: '', priority: priority, isDone: isDone);

void main() {
  test('a task earns more XP at a higher priority', () {
    expect(xpForTask(_task(TaskPriority.low)), 10);
    expect(xpForTask(_task(TaskPriority.medium)), 20);
    expect(xpForTask(_task(TaskPriority.high)), 30);
  });

  test('only completed tasks count', () {
    final progression = Progression.fromTasks([
      _task(TaskPriority.high),
      _task(TaskPriority.low),
      _task(TaskPriority.high, isDone: false),
    ]);

    expect(progression.level, 1);
    expect(progression.xpIntoLevel, 40);
  });

  test('a new list starts at level 1 with no XP', () {
    final progression = Progression.fromTasks(const []);

    expect(progression.level, 1);
    expect(progression.xpIntoLevel, 0);
    expect(progression.xpToNextLevel, 100);
    expect(progression.levelRatio, 0);
  });

  test('each level costs more than the last', () {
    final justBelow = Progression.fromXp(99);
    expect(justBelow.level, 1);
    expect(justBelow.xpIntoLevel, 99);

    final levelTwo = Progression.fromXp(100);
    expect(levelTwo.level, 2);
    expect(levelTwo.xpIntoLevel, 0);
    expect(levelTwo.xpToNextLevel, 200);

    final levelThree = Progression.fromXp(350);
    expect(levelThree.level, 3);
    expect(levelThree.xpIntoLevel, 50);
    expect(levelThree.xpToNextLevel, 300);
    expect(levelThree.levelRatio, closeTo(50 / 300, 0.001));
  });
}
