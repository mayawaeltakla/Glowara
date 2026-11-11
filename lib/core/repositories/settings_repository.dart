/// إعدادات التطبيق: تفضيلات العرض، التذكيرات، والخصوصية.
library glowara.repositories.settings;

import 'package:glowara/core/db/local_database.dart';

/// إعدادات التذكيرات (تُحفظ وتُجدوَل كإشعارات محلية على أندرويد).
class ReminderSettings {
  const ReminderSettings({
    this.waterEnabled = false,
    this.waterIntervalMinutes = 120,
    this.prayerEnabled = true,
    this.quietHoursEnabled = false,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
    this.morningAdhkarEnabled = false,
    this.morningAdhkarHour = 6,
    this.eveningAdhkarEnabled = false,
    this.eveningAdhkarHour = 17,
    this.duaEnabled = false,
    this.duaHour = 21,
  });

  final bool waterEnabled;
  final int waterIntervalMinutes;
  final bool prayerEnabled;
  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietEndHour;
  final bool morningAdhkarEnabled;
  final int morningAdhkarHour;
  final bool eveningAdhkarEnabled;
  final int eveningAdhkarHour;
  final bool duaEnabled;
  final int duaHour;

  ReminderSettings copyWith({
    bool? waterEnabled,
    int? waterIntervalMinutes,
    bool? prayerEnabled,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
    bool? morningAdhkarEnabled,
    int? morningAdhkarHour,
    bool? eveningAdhkarEnabled,
    int? eveningAdhkarHour,
    bool? duaEnabled,
    int? duaHour,
  }) =>
      ReminderSettings(
        waterEnabled: waterEnabled ?? this.waterEnabled,
        waterIntervalMinutes: waterIntervalMinutes ?? this.waterIntervalMinutes,
        prayerEnabled: prayerEnabled ?? this.prayerEnabled,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietStartHour: quietStartHour ?? this.quietStartHour,
        quietEndHour: quietEndHour ?? this.quietEndHour,
        morningAdhkarEnabled: morningAdhkarEnabled ?? this.morningAdhkarEnabled,
        morningAdhkarHour: morningAdhkarHour ?? this.morningAdhkarHour,
        eveningAdhkarEnabled: eveningAdhkarEnabled ?? this.eveningAdhkarEnabled,
        eveningAdhkarHour: eveningAdhkarHour ?? this.eveningAdhkarHour,
        duaEnabled: duaEnabled ?? this.duaEnabled,
        duaHour: duaHour ?? this.duaHour,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'waterEnabled': waterEnabled,
        'waterIntervalMinutes': waterIntervalMinutes,
        'prayerEnabled': prayerEnabled,
        'quietHoursEnabled': quietHoursEnabled,
        'quietStartHour': quietStartHour,
        'quietEndHour': quietEndHour,
        'morningAdhkarEnabled': morningAdhkarEnabled,
        'morningAdhkarHour': morningAdhkarHour,
        'eveningAdhkarEnabled': eveningAdhkarEnabled,
        'eveningAdhkarHour': eveningAdhkarHour,
        'duaEnabled': duaEnabled,
        'duaHour': duaHour,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
        waterEnabled: (j['waterEnabled'] as bool?) ?? false,
        waterIntervalMinutes: (j['waterIntervalMinutes'] as num?)?.toInt() ?? 120,
        prayerEnabled: (j['prayerEnabled'] as bool?) ?? true,
        quietHoursEnabled: (j['quietHoursEnabled'] as bool?) ?? false,
        quietStartHour: (j['quietStartHour'] as num?)?.toInt() ?? 22,
        quietEndHour: (j['quietEndHour'] as num?)?.toInt() ?? 7,
        morningAdhkarEnabled: (j['morningAdhkarEnabled'] as bool?) ?? false,
        morningAdhkarHour: (j['morningAdhkarHour'] as num?)?.toInt() ?? 6,
        eveningAdhkarEnabled: (j['eveningAdhkarEnabled'] as bool?) ?? false,
        eveningAdhkarHour: (j['eveningAdhkarHour'] as num?)?.toInt() ?? 17,
        duaEnabled: (j['duaEnabled'] as bool?) ?? false,
        duaHour: (j['duaHour'] as num?)?.toInt() ?? 21,
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
