import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/repositories/task_repository.dart';
import 'package:glowara/features/worship/adhkar_screen.dart';
import 'package:glowara/features/worship/dua_screen.dart';

import 'support/test_db.dart';

void main() {
  group('adhkar and dua data', () {
    test('every dhikr has text and a positive count', () {
      for (final d in <Dhikr>[...kMorningAdhkar, ...kEveningAdhkar]) {
        expect(d.text.trim(), isNotEmpty);
        expect(d.times, greaterThanOrEqualTo(1));
      }
      expect(kMorningAdhkar, isNotEmpty);
      expect(kEveningAdhkar, isNotEmpty);
    });

    test('texts are clean: no tatweel, emoji or keycap digits', () {
      final bad = RegExp('[ـ‎️⃣\u{1F300}-\u{1FAFF}]', unicode: true);
      final all = <String>[
        for (final d in <Dhikr>[...kMorningAdhkar, ...kEveningAdhkar]) ...<String>[d.text, d.note],
        for (final d in kDuas) ...<String>[d.text, d.intro ?? '', d.note ?? ''],
      ];
      for (final t in all) {
        expect(bad.hasMatch(t), isFalse, reason: t);
      }
    });

    test('duas are not empty and counts are positive', () {
      expect(kDuas, isNotEmpty);
      for (final d in kDuas) {
        expect(d.text.trim(), isNotEmpty);
        expect(d.times, greaterThanOrEqualTo(1));
      }
    });
  });

  group('recurring tasks', () {
    test('completion is tracked per day', () async {
      final db = await openTestDatabase();
      final repo = TaskRepository(db);
      final start = DateTime(2026, 11, 10, 9);
      final task = TaskItem(
        id: 'r1',
        userId: 'u1',
        title: 'Daily',
        dueDateTime: start,
        repeat: RepeatPattern.daily,
        createdAt: start,
      );
      await repo.save(task);

      final day1 = DateTime(2026, 11, 10);
      final day2 = DateTime(2026, 11, 11);
      await repo.toggle(task, day: day1);

      final saved = (await repo.all('u1')).single;
      expect(saved.isDoneOn(day1), isTrue);
      expect(saved.isDoneOn(day2), isFalse);

      await repo.toggle(saved, day: day1);
      expect((await repo.all('u1')).single.isDoneOn(day1), isFalse);
    });

    test('a recurring task is never overdue', () async {
      final db = await openTestDatabase();
      final repo = TaskRepository(db);
      final past = DateTime.now().subtract(const Duration(days: 5));
      await repo.save(TaskItem(
        id: 'r2',
        userId: 'u1',
        title: 'Weekly',
        dueDateTime: past,
        repeat: RepeatPattern.weekly,
        createdAt: past,
      ));
      expect(await repo.overdue('u1'), isEmpty);
    });
  });
}
