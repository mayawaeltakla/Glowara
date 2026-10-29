/// موديلات البيانات الأساسية لتطبيق Glowara.
/// جميع الموديلات غير قابلة للتغيير (immutable) وتدعم التسلسل إلى JSON ومنه
/// للتخزين المحلي والمزامنة السحابية مستقبلاً.
library glowara.models;


/// مساعدة للتحويل من/to تاريخ ISO8601.
class _DateTimeHelper {
  _DateTimeHelper._();
  static String toJson(DateTime? d) => d?.toUtc().toIso8601String() ?? '';
  static DateTime? fromJson(dynamic v) {
    if (v == null || v is! String || v.isEmpty) return null;
    try {
      return DateTime.parse(v).toLocal();
    } catch (_) {
      return null;
    }
  }
}

/// نوع كيان بيانات للمزامنة.
enum SyncStatus { local, synced, conflict, deleted }

extension SyncStatusX on SyncStatus {
  String toJsonValue() => name;
  static SyncStatus fromJsonValue(String v) {
    switch (v) {
      case 'synced': return SyncStatus.synced;
      case 'conflict': return SyncStatus.conflict;
      case 'deleted': return SyncStatus.deleted;
      default: return SyncStatus.local;
    }
  }
}

/// حالة إتمام الصلاة/العبادة.
enum WorshipState { none, completed, skipped }

extension WorshipStateX on WorshipState {
  String toJsonValue() {
    switch (this) {
      case WorshipState.completed: return 'completed';
      case WorshipState.skipped: return 'skipped';
      default: return 'none';
    }
  }
  static WorshipState fromJsonValue(String v) {
    switch (v) {
      case 'completed': return WorshipState.completed;
      case 'skipped': return WorshipState.skipped;
      default: return WorshipState.none;
    }
  }
}

/// نمط التكرار للمهام والعادات.
enum RepeatPattern { none, daily, weekly, customDays }

extension RepeatPatternX on RepeatPattern {
  String toJsonValue() {
    switch (this) {
      case RepeatPattern.daily: return 'daily';
      case RepeatPattern.weekly: return 'weekly';
      case RepeatPattern.customDays: return 'custom';
      default: return 'none';
    }
  }
  static RepeatPattern fromJsonValue(String v) {
    switch (v) {
      case 'daily': return RepeatPattern.daily;
      case 'weekly': return RepeatPattern.weekly;
      case 'custom': return RepeatPattern.customDays;
      default: return RepeatPattern.none;
    }
  }
}

/// حالة إتمام المهمة.
enum TaskState { open, done, reopened }

extension TaskStateX on TaskState {
  String toJsonValue() {
    switch (this) {
      case TaskState.done: return 'done';
      case TaskState.reopened: return 'reopened';
      default: return 'open';
    }
  }
  static TaskState fromJsonValue(String v) {
    switch (v) {
      case 'done': return TaskState.done;
      case 'reopened': return TaskState.reopened;
      default: return TaskState.open;
    }
  }
}

// =============================================================================
// موديل المستخدم
// =============================================================================
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    required this.createdAt,
    this.language = 'ar',
    this.themeId = 'rose',
    this.themeMode = 'system', // system | light | dark
    this.timeZone = 'UTC',
    this.syncStatus = SyncStatus.synced,
    this.lastModified,
  });

  final String id;
  final String? email;
  final String? displayName;
  final DateTime createdAt;
  final String language;
  final String themeId;
  final String themeMode;
  final String timeZone;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'email': email,
        'displayName': displayName,
        'createdAt': _DateTimeHelper.toJson(createdAt),
        'language': language,
        'themeId': themeId,
        'themeMode': themeMode,
        'timeZone': timeZone,
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        language: (json['language'] as String?) ?? 'ar',
        themeId: (json['themeId'] as String?) ?? 'rose',
        themeMode: (json['themeMode'] as String?) ?? 'system',
        timeZone: (json['timeZone'] as String?) ?? 'UTC',
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'synced'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );

  AppUser copyWith({
    String? id, String? email, String? displayName, DateTime? createdAt,
    String? language, String? themeId, String? themeMode, String? timeZone,
    SyncStatus? syncStatus, DateTime? lastModified,
  }) {
    return AppUser(
      id: id ?? this.id, email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      language: language ?? this.language,
      themeId: themeId ?? this.themeId,
      themeMode: themeMode ?? this.themeMode,
      timeZone: timeZone ?? this.timeZone,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

// =============================================================================
// موديل المهمة (تقويم)
// =============================================================================
class TaskItem {
  const TaskItem({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.dueDateTime,
    this.category,
    this.priority = 1,
    this.state = TaskState.open,
    this.repeat = RepeatPattern.none,
    this.customDays = const <int>[],
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime? dueDateTime;
  final String? category;
  final int priority; // 1 منخفضة .. 3 عالية
  final TaskState state;
  final RepeatPattern repeat;
  final List<int> customDays; // أيام الأسبوع 1=الاثنين .. 7=الأحد (مطابق لـ DateTime.weekday)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'userId': userId, 'title': title, 'description': description,
        'dueDateTime': _DateTimeHelper.toJson(dueDateTime), 'category': category,
        'priority': priority, 'state': state.toJsonValue(),
        'repeat': repeat.toJsonValue(),
        'customDays': customDays.map((d) => d).toList(),
        'createdAt': _DateTimeHelper.toJson(createdAt),
        'updatedAt': _DateTimeHelper.toJson(updatedAt),
        'deletedAt': _DateTimeHelper.toJson(deletedAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String,
        userId: json['userId'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        dueDateTime: _DateTimeHelper.fromJson(json['dueDateTime']),
        category: json['category'] as String?,
        priority: (json['priority'] as num?)?.toInt() ?? 1,
        state: TaskStateX.fromJsonValue(json['state'] as String? ?? 'open'),
        repeat: RepeatPatternX.fromJsonValue(json['repeat'] as String? ?? 'none'),
        customDays: (json['customDays'] as List<dynamic>?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        updatedAt: _DateTimeHelper.fromJson(json['updatedAt']),
        deletedAt: _DateTimeHelper.fromJson(json['deletedAt']),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );

  TaskItem copyWith({
    String? id, String? userId, String? title, String? description,
    DateTime? dueDateTime, String? category, int? priority, TaskState? state,
    RepeatPattern? repeat, List<int>? customDays, DateTime? createdAt,
    DateTime? updatedAt, DateTime? deletedAt, SyncStatus? syncStatus,
    DateTime? lastModified,
  }) {
    return TaskItem(
      id: id ?? this.id, userId: userId ?? this.userId,
      title: title ?? this.title, description: description ?? this.description,
      dueDateTime: dueDateTime ?? this.dueDateTime,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      state: state ?? this.state,
      repeat: repeat ?? this.repeat,
      customDays: customDays ?? this.customDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

// =============================================================================
// موديل العادة وسجلها
// =============================================================================
class Habit {
  const Habit({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.schedule = RepeatPattern.daily,
    this.customDays = const <int>[],
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String userId;
  final String name;
  final String? description;
  final RepeatPattern schedule;
  final List<int> customDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'userId': userId, 'name': name, 'description': description,
        'schedule': schedule.toJsonValue(),
        'customDays': customDays.map((d) => d).toList(),
        'isActive': isActive,
        'createdAt': _DateTimeHelper.toJson(createdAt),
        'updatedAt': _DateTimeHelper.toJson(updatedAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        userId: json['userId'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        schedule: RepeatPatternX.fromJsonValue(json['schedule'] as String? ?? 'daily'),
        customDays: (json['customDays'] as List<dynamic>?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
        isActive: (json['isActive'] as bool?) ?? true,
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        updatedAt: _DateTimeHelper.fromJson(json['updatedAt']),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );

  Habit copyWith({String? id, String? userId, String? name, String? description,
    RepeatPattern? schedule, List<int>? customDays, bool? isActive,
    DateTime? createdAt, DateTime? updatedAt, SyncStatus? syncStatus,
    DateTime? lastModified}) {
    return Habit(
      id: id ?? this.id, userId: userId ?? this.userId, name: name ?? this.name,
      description: description ?? this.description,
      schedule: schedule ?? this.schedule,
      customDays: customDays ?? this.customDays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.date, // Date only (yyyy-MM-dd)
    this.state = WorshipState.none,
    this.note,
    required this.createdAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String habitId;
  final String date;
  final WorshipState state;
  final String? note;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'habitId': habitId, 'date': date,
        'state': state.toJsonValue(), 'note': note,
        'createdAt': _DateTimeHelper.toJson(createdAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory HabitLog.fromJson(Map<String, dynamic> json) => HabitLog(
        id: json['id'] as String,
        habitId: json['habitId'] as String,
        date: json['date'] as String,
        state: WorshipStateX.fromJsonValue(json['state'] as String? ?? 'none'),
        note: json['note'] as String?,
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );
}

// =============================================================================
// عنصر تعبدي (صلاة/قرآن/أذكار/تسبيح/دعاء)
// =============================================================================
class WorshipItem {
  const WorshipItem({
    required this.id,
    required this.type, // prayer | quran | adkar | tasbih | istighfar | dua
    required this.reference, // مرجع النص (رقم الآية، معرف الأذكار، إلخ)
    required this.titleAr,
    required this.titleEn,
    this.source, // مصدر النص الموثوق
    this.order = 0,
    this.isEnabled = true,
    this.isPersonal = false, // نص من صاحبة التطبيق وليس منقولاً
  });

  final String id;
  final String type;
  final String reference;
  final String titleAr;
  final String titleEn;
  final String? source; // مرجع المصدر الموثوق
  final int order;
  final bool isEnabled;
  final bool isPersonal;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'type': type, 'reference': reference,
        'titleAr': titleAr, 'titleEn': titleEn, 'source': source,
        'order': order, 'isEnabled': isEnabled, 'isPersonal': isPersonal,
      };

  factory WorshipItem.fromJson(Map<String, dynamic> json) => WorshipItem(
        id: json['id'] as String,
        type: json['type'] as String,
        reference: json['reference'] as String,
        titleAr: json['titleAr'] as String,
        titleEn: json['titleEn'] as String,
        source: json['source'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 0,
        isEnabled: (json['isEnabled'] as bool?) ?? true,
        isPersonal: (json['isPersonal'] as bool?) ?? false,
      );
}

/// سجل قراءة القرآن/الأذكار.
class ReadingLog {
  const ReadingLog({
    required this.id,
    this.userId = '',
    required this.itemId,
    this.surah,
    this.ayahFrom,
    this.ayahTo,
    required this.completedAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String userId;
  final String itemId;
  final int? surah;
  final int? ayahFrom;
  final int? ayahTo;
  final DateTime completedAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'userId': userId, 'itemId': itemId, 'surah': surah,
        'ayahFrom': ayahFrom, 'ayahTo': ayahTo,
        'completedAt': _DateTimeHelper.toJson(completedAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory ReadingLog.fromJson(Map<String, dynamic> json) => ReadingLog(
        id: json['id'] as String,
        userId: (json['userId'] as String?) ?? '',
        itemId: json['itemId'] as String,
        surah: (json['surah'] as num?)?.toInt(),
        ayahFrom: (json['ayahFrom'] as num?)?.toInt(),
        ayahTo: (json['ayahTo'] as num?)?.toInt(),
        completedAt: _DateTimeHelper.fromJson(json['completedAt']) ?? DateTime.now(),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );
}

// =============================================================================
// المزاج والمذكرات
// =============================================================================
class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.value, // 1..5
    this.note,
    required this.createdAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String userId;
  final String date;
  final int value;
  final String? note;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'userId': userId, 'date': date, 'value': value,
        'note': note, 'createdAt': _DateTimeHelper.toJson(createdAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
        id: json['id'] as String,
        userId: json['userId'] as String,
        date: json['date'] as String,
        value: (json['value'] as num).toInt(),
        note: json['note'] as String?,
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'userId': userId, 'title': title, 'content': content,
        'createdAt': _DateTimeHelper.toJson(createdAt),
        'updatedAt': _DateTimeHelper.toJson(updatedAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        userId: json['userId'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        updatedAt: _DateTimeHelper.fromJson(json['updatedAt']),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );

  JournalEntry copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    DateTime? lastModified,
  }) =>
      JournalEntry(
        id: id,
        userId: userId,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
      );
}

// =============================================================================
// الدراسة
// =============================================================================
class StudySubject {
  const StudySubject({
    required this.id,
    required this.userId,
    required this.name,
    this.color,
    this.icon,
    this.goal,
    this.examDate,
    this.notes,
    required this.createdAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String userId;
  final String name;
  final String? color;
  final String? icon;
  final String? goal;
  final DateTime? examDate;
  final String? notes;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'userId': userId, 'name': name, 'color': color,
        'icon': icon, 'goal': goal, 'examDate': _DateTimeHelper.toJson(examDate),
        'notes': notes, 'createdAt': _DateTimeHelper.toJson(createdAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory StudySubject.fromJson(Map<String, dynamic> json) => StudySubject(
        id: json['id'] as String,
        userId: json['userId'] as String,
        name: json['name'] as String,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        goal: json['goal'] as String?,
        examDate: _DateTimeHelper.fromJson(json['examDate']),
        notes: json['notes'] as String?,
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );

  StudySubject copyWith({
    String? name,
    String? color,
    String? icon,
    String? goal,
    DateTime? examDate,
    String? notes,
    SyncStatus? syncStatus,
    DateTime? lastModified,
  }) =>
      StudySubject(
        id: id,
        userId: userId,
        name: name ?? this.name,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        goal: goal ?? this.goal,
        examDate: examDate ?? this.examDate,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
      );
}

class StudyUnit {
  const StudyUnit({
    required this.id,
    required this.subjectId,
    required this.title,
    this.state = TaskState.open,
    required this.createdAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String subjectId;
  final String title;
  final TaskState state;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'subjectId': subjectId, 'title': title,
        'state': state.toJsonValue(),
        'createdAt': _DateTimeHelper.toJson(createdAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory StudyUnit.fromJson(Map<String, dynamic> json) => StudyUnit(
        id: json['id'] as String,
        subjectId: json['subjectId'] as String,
        title: json['title'] as String,
        state: TaskStateX.fromJsonValue(json['state'] as String? ?? 'open'),
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );

  StudyUnit copyWith({String? title, TaskState? state, SyncStatus? syncStatus, DateTime? lastModified}) =>
      StudyUnit(
        id: id,
        subjectId: subjectId,
        title: title ?? this.title,
        state: state ?? this.state,
        createdAt: createdAt,
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
      );
}

class StudySession {
  const StudySession({
    required this.id,
    this.userId = '',
    required this.subjectId,
    required this.startedAt,
    this.endedAt,
    this.durationMinutes,
    this.notes,
    required this.createdAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String userId;
  final String subjectId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final String? notes;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'userId': userId, 'subjectId': subjectId,
        'startedAt': _DateTimeHelper.toJson(startedAt),
        'endedAt': _DateTimeHelper.toJson(endedAt),
        'durationMinutes': durationMinutes, 'notes': notes,
        'createdAt': _DateTimeHelper.toJson(createdAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'] as String,
        userId: (json['userId'] as String?) ?? '',
        subjectId: json['subjectId'] as String,
        startedAt: _DateTimeHelper.fromJson(json['startedAt']) ?? DateTime.now(),
        endedAt: _DateTimeHelper.fromJson(json['endedAt']),
        durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
        notes: json['notes'] as String?,
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );

  StudySession copyWith({
    DateTime? endedAt,
    int? durationMinutes,
    String? notes,
    SyncStatus? syncStatus,
    DateTime? lastModified,
  }) =>
      StudySession(
        id: id,
        userId: userId,
        subjectId: subjectId,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
      );
}

// =============================================================================
// العناية والصحة (الماء، الوجبات)
// =============================================================================
class WaterLog {
  const WaterLog({
    required this.id,
    required this.userId,
    required this.date,
    this.amountMl = 0,
    required this.createdAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String userId;
  final String date;
  final int amountMl;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'userId': userId, 'date': date, 'amountMl': amountMl,
        'createdAt': _DateTimeHelper.toJson(createdAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory WaterLog.fromJson(Map<String, dynamic> json) => WaterLog(
        id: json['id'] as String,
        userId: json['userId'] as String,
        date: json['date'] as String,
        amountMl: (json['amountMl'] as num?)?.toInt() ?? 0,
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );
}

class MealNote {
  const MealNote({
    required this.id,
    required this.userId,
    required this.dateTime,
    this.mealType = 'meal',
    this.note,
    required this.createdAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String userId;
  final DateTime dateTime;
  /// breakfast | lunch | dinner | snack | meal
  final String mealType;
  final String? note;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'userId': userId,
        'dateTime': _DateTimeHelper.toJson(dateTime),
        'mealType': mealType, 'note': note,
        'createdAt': _DateTimeHelper.toJson(createdAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _DateTimeHelper.toJson(lastModified),
      };

  factory MealNote.fromJson(Map<String, dynamic> json) => MealNote(
        id: json['id'] as String,
        userId: json['userId'] as String,
        dateTime: _DateTimeHelper.fromJson(json['dateTime']) ?? DateTime.now(),
        mealType: (json['mealType'] as String?) ?? 'meal',
        note: json['note'] as String?,
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        syncStatus: SyncStatusX.fromJsonValue(json['syncStatus'] as String? ?? 'local'),
        lastModified: _DateTimeHelper.fromJson(json['lastModified']),
      );
}

// =============================================================================
// سجل المزامنة (offline queue)
// =============================================================================
class SyncRecord {
  const SyncRecord({
    required this.id,
    required this.operation, // create | update | delete
    required this.entityType, // task | habit | habitLog | readingLog | mood | journal | subject | unit | session | water | meal | user
    required this.entityId,
    this.payload,
    required this.status,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttempt,
    this.errorMessage,
  });

  final String id;
  final String operation;
  final String entityType;
  final String entityId;
  final Map<String, dynamic>? payload;
  final SyncStatus status;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastAttempt;
  final String? errorMessage;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'operation': operation, 'entityType': entityType,
        'entityId': entityId, 'payload': payload,
        'status': status.toJsonValue(), 'createdAt': _DateTimeHelper.toJson(createdAt),
        'retryCount': retryCount,
        'lastAttempt': _DateTimeHelper.toJson(lastAttempt),
        'errorMessage': errorMessage,
      };

  factory SyncRecord.fromJson(Map<String, dynamic> json) => SyncRecord(
        id: json['id'] as String,
        operation: json['operation'] as String,
        entityType: json['entityType'] as String,
        entityId: json['entityId'] as String,
        payload: json['payload'] != null
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : null,
        status: SyncStatusX.fromJsonValue(json['status'] as String? ?? 'local'),
        createdAt: _DateTimeHelper.fromJson(json['createdAt']) ?? DateTime.now(),
        retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
        lastAttempt: _DateTimeHelper.fromJson(json['lastAttempt']),
        errorMessage: json['errorMessage'] as String?,
      );
}

/// معرف فريد بسيط (بدون حزمة خارجية).
String uniqueId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final random = (now * 1000 + DateTime.now().millisecond) % 900000 + 100000;
  return '${now}_$random';
}
