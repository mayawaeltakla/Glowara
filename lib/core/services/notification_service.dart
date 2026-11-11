/// التذكيرات: إشعارات محلية مجدولة يوميًا (أذكار الصباح والمساء، الأدعية، الماء).
///
/// لا شيء يُرسَل خارج الجهاز. على الويب لا تعمل الإشعارات المجدولة فيُتجاهل الطلب.
library glowara.services.notifications;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/utils/app_log.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// واجهة مجدول التذكيرات (تُستبدل بنسخة وهمية في الاختبارات).
abstract class ReminderScheduler {
  /// يلغي المجدول السابق ويجدول حسب [settings].
  Future<void> apply(ReminderSettings settings, {required bool arabic});
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

  @override
  Future<void> apply(ReminderSettings s, {required bool arabic}) async {
    if (kIsWeb) return;
    try {
      await _init();
      await _plugin.cancelAll();

      final any = s.morningAdhkarEnabled || s.eveningAdhkarEnabled || s.duaEnabled || s.waterEnabled;
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
