import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

void main() {
  group('date helpers', () {
    test('dateKey pads month and day', () {
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(monthKey(DateTime(2026, 10, 28)), '2026-10');
    });

    test('startOfWeek is Monday and stable', () {
      final monday = startOfWeek(DateTime(2026, 10, 28)); // Wednesday
      expect(monday.weekday, DateTime.monday);
      expect(dateKey(monday), '2026-10-26');
      expect(dateKey(endOfWeek(monday)), '2026-11-01');
    });

    test('inRange includes both ends', () {
      final from = DateTime(2026, 10, 1);
      final to = DateTime(2026, 10, 3);
      expect(inRange(DateTime(2026, 10, 1, 23, 59), from, to), isTrue);
      expect(inRange(DateTime(2026, 10, 3), from, to), isTrue);
      expect(inRange(DateTime(2026, 10, 4), from, to), isFalse);
    });
  });

  group('models round-trip', () {
    test('TaskItem survives JSON round-trip', () {
      final task = TaskItem(
        id: 'task_1',
        userId: 'user_1',
        title: 'مراجعة الدرس',
        description: 'صفحة 12',
        dueDateTime: DateTime(2026, 10, 28, 9, 30),
        priority: 2,
        repeat: RepeatPattern.weekly,
        customDays: const <int>[1, 3, 5],
        createdAt: DateTime(2026, 10, 27),
      );

      final restored = TaskItem.fromJson(task.toJson());
      expect(restored.id, task.id);
      expect(restored.userId, task.userId);
      expect(restored.title, task.title);
      expect(restored.priority, 2);
      expect(restored.repeat, RepeatPattern.weekly);
      expect(restored.customDays, <int>[1, 3, 5]);
      expect(restored.state, TaskState.open);
    });

    test('JournalEntry copyWith keeps identity', () {
      final entry = JournalEntry(
        id: 'journal_1',
        userId: 'user_1',
        title: 'يوم هادئ',
        content: 'كتبت شيئًا',
        createdAt: DateTime(2026, 10, 27),
      );

      final updated = entry.copyWith(
        title: 'يوم هادئ جدًا',
        updatedAt: DateTime(2026, 10, 28),
      );

      expect(updated.id, entry.id);
      expect(updated.userId, entry.userId);
      expect(updated.title, 'يوم هادئ جدًا');
      expect(updated.content, entry.content);
      expect(updated.createdAt, entry.createdAt);
    });

    test('StudySession keeps optional legacy userId semantics', () {
      final legacy = StudySession.fromJson(<String, dynamic>{
        'id': 'session_1',
        'subjectId': 'subject_1',
        'startedAt': DateTime(2026, 10, 28).toUtc().toIso8601String(),
        'durationMinutes': 25,
        'createdAt': DateTime(2026, 10, 28).toUtc().toIso8601String(),
      });
      expect(legacy.userId, '');
      expect(legacy.durationMinutes, 25);
    });
  });

  group('statistics and settings', () {
    test('PeriodStats rates avoid division by zero', () {
      const empty = PeriodStats();
      expect(empty.taskRate, 0.0);
      expect(empty.habitRate, 0.0);
      expect(empty.careRate, 0.0);
      expect(empty.hasData, isFalse);

      const stats = PeriodStats(
        tasksTotal: 4,
        tasksDone: 2,
        habitsScheduled: 5,
        habitsDone: 5,
      );
      expect(stats.taskRate, 0.5);
      expect(stats.habitRate, 1.0);
      expect(stats.hasData, isTrue);
    });

    test('ReminderSettings survives JSON and copyWith', () {
      const settings = ReminderSettings(
        waterEnabled: true,
        quietHoursEnabled: true,
        quietStartHour: 23,
        quietEndHour: 6,
      );
      final restored = ReminderSettings.fromJson(settings.toJson());
      expect(restored.waterEnabled, isTrue);
      expect(restored.quietStartHour, 23);
      expect(restored.quietEndHour, 6);

      final changed = restored.copyWith(waterEnabled: false);
      expect(changed.waterEnabled, isFalse);
      expect(changed.quietStartHour, 23);
    });
  });
}
