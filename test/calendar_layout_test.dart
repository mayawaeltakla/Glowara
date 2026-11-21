import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/features/calendar/calendar_layout.dart';

void main() {
  group('week start', () {
    test('Arabic starts on Sunday, English on Monday', () {
      expect(weekStartFor('ar'), DateTime.sunday);
      expect(weekStartFor('en'), DateTime.monday);
    });

    test('column order follows the week start', () {
      expect(weekdayOrder(DateTime.sunday), <int>[7, 1, 2, 3, 4, 5, 6]);
      expect(weekdayOrder(DateTime.monday), <int>[1, 2, 3, 4, 5, 6, 7]);
    });
  });

  group('month grid', () {
    test('always 42 consecutive calendar days that contain the whole month', () {
      for (final month in <DateTime>[
        DateTime(2026, 2), // 28 يومًا
        DateTime(2028, 2), // كبيس: 29 يومًا
        DateTime(2026, 4), // 30 يومًا
        DateTime(2026, 12), // 31 يومًا وحدّ السنة
        DateTime(2027, 1),
      ]) {
        for (final weekStart in <int>[DateTime.sunday, DateTime.monday, DateTime.saturday]) {
          final days = monthGridDays(month, weekStart);
          expect(days, hasLength(42), reason: '$month/$weekStart');
          expect(days.first.weekday, weekStart, reason: '$month/$weekStart');
          for (var i = 0; i < days.length - 1; i++) {
            expect(days[i + 1], DateTime(days[i].year, days[i].month, days[i].day + 1));
          }
          final inMonth = days.where((d) => isInMonth(d, month)).length;
          expect(inMonth, daysInMonth(month), reason: '$month/$weekStart');
        }
      }
    });

    test('November 2026 starts on a Sunday', () {
      expect(DateTime(2026, 11, 1).weekday, DateTime.sunday);
      expect(monthGridDays(DateTime(2026, 11), DateTime.sunday).first, DateTime(2026, 11, 1));
      // الاثنين أول الأسبوع: يبدأ العرض بالاثنين السابق (26 أكتوبر).
      expect(monthGridDays(DateTime(2026, 11), DateTime.monday).first, DateTime(2026, 10, 26));
    });

    test('a month does not always start in the same column', () {
      final nov = monthGridDays(DateTime(2026, 11), DateTime.sunday);
      final dec = monthGridDays(DateTime(2026, 12), DateTime.sunday);
      final novColumn = nov.indexWhere((d) => d.day == 1 && d.month == 11);
      final decColumn = dec.indexWhere((d) => d.day == 1 && d.month == 12);
      expect(novColumn, 0);
      expect(decColumn, 2);
    });

    test('December grid reaches into January of the next year', () {
      final days = monthGridDays(DateTime(2026, 12), DateTime.sunday);
      expect(days.first, DateTime(2026, 11, 29));
      expect(days.last, DateTime(2027, 1, 9));
    });
  });

  group('month arithmetic', () {
    test('addMonths crosses year boundaries both ways', () {
      expect(addMonths(DateTime(2026, 12), 1), DateTime(2027, 1));
      expect(addMonths(DateTime(2027, 1), -1), DateTime(2026, 12));
      expect(addMonths(DateTime(2026, 11), 14), DateTime(2028, 1));
      expect(addMonths(DateTime(2026, 11), -11), DateTime(2025, 12));
    });

    test('addDays uses calendar days', () {
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2028, 3, 1), -1), DateTime(2028, 2, 29));
      expect(addDays(DateTime(2027, 3, 1), -1), DateTime(2027, 2, 28));
    });
  });

  group('parseDateKey', () {
    test('accepts valid dates including a leap day', () {
      expect(parseDateKey('2026-11-21'), DateTime(2026, 11, 21));
      expect(parseDateKey('2028-02-29'), DateTime(2028, 2, 29));
    });

    test('rejects impossible or malformed values', () {
      expect(parseDateKey(null), isNull);
      expect(parseDateKey(''), isNull);
      expect(parseDateKey('2027-02-29'), isNull);
      expect(parseDateKey('2026-02-30'), isNull);
      expect(parseDateKey('2026-13-01'), isNull);
      expect(parseDateKey('2026-1-1'), isNull);
      expect(parseDateKey('21-11-2026'), isNull);
      expect(parseDateKey('2026-11-21T10:00'), isNull);
    });
  });
}
