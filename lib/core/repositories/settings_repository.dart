/// إعدادات التطبيق: تفضيلات العرض، التذكيرات، والخصوصية.
library glowara.repositories.settings;

import 'package:glowara/core/db/local_database.dart';

/// إعدادات التذكيرات (تُحفظ وتُطبَّق داخل التطبيق حاليًا).
class ReminderSettings {
  const ReminderSettings({
    this.waterEnabled = false,
    this.waterIntervalMinutes = 120,
    this.prayerEnabled = true,
    this.quietHoursEnabled = false,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
  });

  final bool waterEnabled;
  final int waterIntervalMinutes;
  final bool prayerEnabled;
  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietEndHour;

  ReminderSettings copyWith({
    bool? waterEnabled,
    int? waterIntervalMinutes,
    bool? prayerEnabled,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
  }) =>
      ReminderSettings(
        waterEnabled: waterEnabled ?? this.waterEnabled,
        waterIntervalMinutes: waterIntervalMinutes ?? this.waterIntervalMinutes,
        prayerEnabled: prayerEnabled ?? this.prayerEnabled,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietStartHour: quietStartHour ?? this.quietStartHour,
        quietEndHour: quietEndHour ?? this.quietEndHour,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'waterEnabled': waterEnabled,
        'waterIntervalMinutes': waterIntervalMinutes,
        'prayerEnabled': prayerEnabled,
        'quietHoursEnabled': quietHoursEnabled,
        'quietStartHour': quietStartHour,
        'quietEndHour': quietEndHour,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
        waterEnabled: (j['waterEnabled'] as bool?) ?? false,
        waterIntervalMinutes: (j['waterIntervalMinutes'] as num?)?.toInt() ?? 120,
        prayerEnabled: (j['prayerEnabled'] as bool?) ?? true,
        quietHoursEnabled: (j['quietHoursEnabled'] as bool?) ?? false,
        quietStartHour: (j['quietStartHour'] as num?)?.toInt() ?? 22,
        quietEndHour: (j['quietEndHour'] as num?)?.toInt() ?? 7,
      );
}

/// تفضيلات العرض.
class DisplaySettings {
  const DisplaySettings({
    this.showMotivation = true,
    this.useWesternDigits = false,
    this.compactCards = false,
  });

  final bool showMotivation;
  final bool useWesternDigits;
  final bool compactCards;

  DisplaySettings copyWith({
    bool? showMotivation,
    bool? useWesternDigits,
    bool? compactCards,
  }) =>
      DisplaySettings(
        showMotivation: showMotivation ?? this.showMotivation,
        useWesternDigits: useWesternDigits ?? this.useWesternDigits,
        compactCards: compactCards ?? this.compactCards,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'showMotivation': showMotivation,
        'useWesternDigits': useWesternDigits,
        'compactCards': compactCards,
      };

  factory DisplaySettings.fromJson(Map<String, dynamic> j) => DisplaySettings(
        showMotivation: (j['showMotivation'] as bool?) ?? true,
        useWesternDigits: (j['useWesternDigits'] as bool?) ?? false,
        compactCards: (j['compactCards'] as bool?) ?? false,
      );
}

class SettingsRepository {
  SettingsRepository(this._db);

  final LocalDatabase _db;

  static const _kReminders = 'reminders';
  static const _kDisplay = 'display';

  Future<T?> get<T>(String key) async {
    final value = await _db.getSetting(key);
    return value is T ? value : null;
  }

  Future<void> set(String key, Object? value) => _db.setSetting(key, value);

  Future<void> remove(String key) => _db.setSetting(key, null);

  Future<ReminderSettings> reminders() async {
    final raw = await _db.getSetting(_kReminders);
    if (raw is Map) return ReminderSettings.fromJson(Map<String, dynamic>.from(raw));
    return const ReminderSettings();
  }

  Future<void> saveReminders(ReminderSettings value) =>
      _db.setSetting(_kReminders, value.toJson());

  Future<DisplaySettings> display() async {
    final raw = await _db.getSetting(_kDisplay);
    if (raw is Map) return DisplaySettings.fromJson(Map<String, dynamic>.from(raw));
    return const DisplaySettings();
  }

  Future<void> saveDisplay(DisplaySettings value) =>
      _db.setSetting(_kDisplay, value.toJson());

  /// هدف الماء اليومي (مل).
  Future<int> waterGoalMl() async {
    final v = await _db.getSetting('water_goal_ml');
    return v is num ? v.toInt() : 2000;
  }

  Future<void> setWaterGoalMl(int ml) => _db.setSetting('water_goal_ml', ml);

  Future<int> cupSizeMl() async {
    final v = await _db.getSetting('cup_size_ml');
    return v is num ? v.toInt() : 250;
  }

  Future<void> setCupSizeMl(int ml) => _db.setSetting('cup_size_ml', ml);
}
