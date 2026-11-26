/// منطق شبكة التقويم الشهري (دوال نقية بلا واجهة).
///
/// كل الأيام تُبنى بحساب التقويم المحلي `DateTime(y, m, d)` لا بإضافة 24 ساعة،
/// فلا تنزاح عند تغيّر التوقيت الصيفي.
library glowara.feature.calendar.layout;

/// أول أيام الأسبوع: الأحد للعربية والاثنين لغيرها (قيم `DateTime.weekday`).
int weekStartFor(String locale) => locale == 'ar' ? DateTime.sunday : DateTime.monday;

/// أيام الأسبوع بترتيب الأعمدة (قيم `DateTime.weekday` من 1 إلى 7).
List<int> weekdayOrder(int weekStart) =>
    List<int>.generate(7, (int i) => ((weekStart - 1 + i) % 7) + 1);

DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// الشهر بعد [delta] أشهر (يقبل سالبًا)، يتخطى حدود السنة تلقائيًا.
DateTime addMonths(DateTime month, int delta) => DateTime(month.year, month.month + delta, 1);

/// 42 يومًا (6 أسابيع) تغطي [month]، تبدأ بأول عمود قبل أو عند أول الشهر.
List<DateTime> monthGridDays(DateTime month, int weekStart) {
  final first = DateTime(month.year, month.month, 1);
  final offset = (first.weekday - weekStart + 7) % 7;
  return List<DateTime>.generate(
    42,
    (int i) => DateTime(first.year, first.month, 1 - offset + i),
  );
}

bool isInMonth(DateTime day, DateTime month) =>
    day.year == month.year && day.month == month.month;

/// اليوم المجاور لـ [day] بعد [delta] يومًا (يقبل سالبًا).
DateTime addDays(DateTime day, int delta) => DateTime(day.year, day.month, day.day + delta);

/// أول يوم في الأسبوع الذي يحوي [day] (بحساب التقويم المحلي لا بإضافة 24 ساعة).
DateTime weekStartOf(DateTime day, int weekStart) {
  final offset = (day.weekday - weekStart + 7) % 7;
  return DateTime(day.year, day.month, day.day - offset);
}

/// آخر يوم (اليوم السابع) في الأسبوع الذي يبدأ في [start].
DateTime weekEndOf(DateTime start) => DateTime(start.year, start.month, start.day + 6);
