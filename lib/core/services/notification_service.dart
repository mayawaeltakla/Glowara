/// التذكيرات: إشعارات محلية مجدولة يوميًا (أذكار الصباح والمساء، الأدعية، الماء).
///
/// لا شيء يُرسَل خارج الجهاز. على الويب لا تعمل الإشعارات المجدولة فيُتجاهل الطلب.
library glowara.services.notifications;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/services/prayer_service.dart';
import 'package:glowara/core/utils/app_log.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// واجهة مجدول التذكيرات (تُستبدل بنسخة وهمية في الاختبارات).
abstract class ReminderScheduler {
  /// يلغي المجدول السابق ويجدول حسب [settings] (و[prayer] لتذكير أوقات الصلاة).
  Future<void> apply(ReminderSettings settings, {required bool arabic, PrayerPlan? prayer});
}

/// اختيارات المستخدمة لحساب المواقيت (مدينة، طريقة، مذهب).
class PrayerPlan {
  const PrayerPlan({required this.cityId, required this.method, required this.hanafi});

  final String cityId;
  final String method;
  final bool hanafi;
}

class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const int _morningId = 1;
  static const int _eveningId = 2;
  static const int _duaId = 3;
  static const int _waterBase = 100;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  Future<void> _requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// أقرب وقت قادم لهذه الساعة (محليًا) كلحظة مطلقة.
  tz.TZDateTime _next(int hour, int minute) {
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return tz.TZDateTime.from(t, tz.UTC);
  }

  Future<void> _daily(int id, int hour, int minute, String title, String body) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      _next(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'glowara_reminders',
          'Glowara reminders',
          channelDescription: 'Adhkar, dua and water reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static const int _prayerBase = 200;

  /// تذكير بكل صلاة للأيام السبعة القادمة (تتغير المواقيت يوميًا فلا يصح تكرار ثابت).
  /// يُعاد الجدول كلما فُتح التطبيق، فيتجدد الأفق تلقائيًا.
  Future<void> _prayers(PrayerPlan plan, bool arabic) async {
    final city = prayerCityById(plan.cityId);
    const names = <String, (String, String)>{
      'fajr': ('الفجر', 'Fajr'),
      'dhuhr': ('الظهر', 'Dhuhr'),
      'asr': ('العصر', 'Asr'),
      'maghrib': ('المغرب', 'Maghrib'),
      'isha': ('العشاء', 'Isha'),
    };
    final now = DateTime.now();
    for (var d = 0; d < 7; d++) {
      final date = now.add(Duration(days: d));
      final day = computePrayerDay(city: city, method: plan.method, hanafi: plan.hanafi, date: date);
      var i = 0;
      for (final (id, time) in day.entries) {
        if (id == 'sunrise') continue;
        final idx = i++;
        if (!time.isAfter(now)) continue;
        final label = names[id]!;
        await _plugin.zonedSchedule(
          _prayerBase + d * 10 + idx,
          arabic ? 'حان وقت صلاة ${label.$1}' : '${label.$2} prayer time',
          arabic ? city.nameAr : city.nameEn,
          tz.TZDateTime.from(time, tz.UTC),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'glowara_prayer',
              'Prayer times',
              channelDescription: 'Prayer time reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  @override
  Future<void> apply(ReminderSettings s, {required bool arabic, PrayerPlan? prayer}) async {
    if (kIsWeb) return;
    try {
      await _init();
      await _plugin.cancelAll();

      final any = s.morningAdhkarEnabled ||
          s.eveningAdhkarEnabled ||
          s.duaEnabled ||
          s.waterEnabled ||
          s.prayerNotifyEnabled;
      if (!any) return;
      await _requestPermission();

      if (s.morningAdhkarEnabled) {
        await _daily(
          _morningId,
          s.morningAdhkarHour,
          0,
          arabic ? 'أذكار الصباح' : 'Morning adhkar',
          arabic ? 'حان وقت أذكار الصباح' : 'It is time for your morning adhkar',
        );
      }
      if (s.eveningAdhkarEnabled) {
        await _daily(
          _eveningId,
          s.eveningAdhkarHour,
          0,
          arabic ? 'أذكار المساء' : 'Evening adhkar',
          arabic ? 'حان وقت أذكار المساء' : 'It is time for your evening adhkar',
        );
      }
      if (s.duaEnabled) {
        await _daily(
          _duaId,
          s.duaHour,
          0,
          arabic ? 'الدعاء' : 'Dua',
          arabic ? 'لا تنسي أدعية اليوم' : 'Do not forget today’s duas',
        );
      }
      if (s.prayerNotifyEnabled && prayer != null) {
        await _prayers(prayer, arabic);
      }
      if (s.waterEnabled) {
        // نوزّع التذكيرات على ساعات اليقظة (خارج ساعات الهدوء) بفاصل الماء.
        final from = s.quietHoursEnabled ? s.quietEndHour : 8;
        var to = s.quietHoursEnabled ? s.quietStartHour : 22;
        if (to <= from) to = 22;
        final step = s.waterIntervalMinutes.clamp(30, 480);
        var minutes = from * 60;
        var i = 0;
        while (minutes < to * 60 && i < 24) {
          await _daily(
            _waterBase + i,
            minutes ~/ 60,
            minutes % 60,
            arabic ? 'الماء' : 'Water',
            arabic ? 'حان وقت كوب ماء' : 'Time for a glass of water',
          );
          minutes += step;
          i++;
        }
      }
    } catch (e, st) {
      // التذكيرات ميزة إضافية: فشلها لا يجب أن يوقف التطبيق.
      logError('LocalReminderScheduler.apply', e, st);
    }
  }
}
