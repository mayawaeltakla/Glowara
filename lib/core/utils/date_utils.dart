/// أدوات التاريخ المشتركة.
library glowara.utils.dates;

import 'package:intl/intl.dart';

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// بداية الأسبوع (الاثنين) — ثابت لتفادي اختلاف المناطق.
DateTime startOfWeek(DateTime d) {
  final day = startOfDay(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime endOfWeek(DateTime d) => startOfWeek(d).add(const Duration(days: 6));

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime d) => isSameDay(d, DateTime.now());

/// أسماء الأشهر العربية/الإنجليزية عبر intl بعد تهيئة l10n.
String formatMonthYear(DateTime d, String locale) =>
    DateFormat.yMMMM(locale).format(d);

String formatFullDate(DateTime d, String locale) =>
    DateFormat.yMMMMEEEEd(locale).format(d);

String formatShortDate(DateTime d, String locale) =>
    DateFormat.MMMd(locale).format(d);

String formatTime(DateTime d, String locale) =>
    DateFormat.jm(locale).format(d);

/// تحويل الأرقام العربية-الهندية إلى غربية (اختياري للعرض).
String westernDigits(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const western = '0123456789';
  var out = input;
  for (var i = 0; i < arabic.length; i++) {
    out = out.replaceAll(arabic[i], western[i]);
  }
  return out;
}

/// هل التاريخ يقع ضمن نطاق (شامل الطرفين)؟
bool inRange(DateTime date, DateTime from, DateTime to) {
  final d = startOfDay(date);
  return !d.isBefore(startOfDay(from)) && !d.isAfter(startOfDay(to));
}

/// يقرأ مفتاح تاريخ بصيغة `YYYY-MM-DD` ويعيد `null` إن كان غير صالح (مثل
/// `2026-02-30`). يُستعمل لقراءة معاملات الروابط بأمان.
DateTime? parseDateKey(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
