import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/repositories/task_repository.dart';
import 'package:glowara/core/services/widget_sync.dart';

import 'support/test_db.dart';

class _Store implements WidgetStore {
  final Map<String, String> data = <String, String>{};
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> remove(String key) async => data.remove(key);
}

void main() {
  late LocalDatabase db;
  late SettingsRepository settings;
  late _Store store;
  final now = DateTime(2026, 11, 25, 10);

  WidgetSync make({bool supported = true}) => WidgetSync(settings: settings, db: db, store: store, supported: supported);

  Future<void> task(String id, String user, DateTime due, {TaskState state = TaskState.open, String title = 'سر'}) =>
      TaskRepository(db).save(TaskItem(id: id, userId: user, title: title, dueDateTime: due, state: state, createdAt: now));

  setUp(() async {
    db = await openTestDatabase();
    settings = SettingsRepository(db);
    store = _Store();
  });

  test('line text is plain, plural-aware and in the chosen language', () {
    expect(widgetLine(0, 'ar'), 'يوم هادئ، لا مهام اليوم');
    expect(widgetLine(1, 'ar'), 'مهمة واحدة اليوم');
    expect(widgetLine(2, 'ar'), 'مهمتان اليوم');
    expect(widgetLine(5, 'ar'), '5 مهام اليوم');
    expect(widgetLine(12, 'ar'), '12 مهمة اليوم');
    expect(widgetLine(0, 'en'), 'A quiet day, no tasks today');
    expect(widgetLine(1, 'en'), '1 task today');
    expect(widgetLine(3, 'en'), '3 tasks today');
  });

  test('off by default: nothing is written', () async {
    await task('a', 'u1', DateTime(2026, 11, 25, 15));
    await make().refresh('u1', 'ar', now: now);
    expect(store.data, isEmpty);
    expect(await make().enabled('u1'), isFalse);
  });

  test('when on, counts only my open tasks due today and never writes a task title', () async {
    await task('a', 'u1', DateTime(2026, 11, 25, 15), title: 'موعد الطبيبة السري');
    await task('b', 'u1', DateTime(2026, 11, 25, 18));
    await task('done', 'u1', DateTime(2026, 11, 25, 9), state: TaskState.done);
    await task('tomorrow', 'u1', DateTime(2026, 11, 26, 9));
    await task('other', 'u2', DateTime(2026, 11, 25, 9));
    await make().setEnabled('u1', true, 'ar', now: now);
    expect(store.data[kWidgetTitleKey], 'غلوارا');
    expect(store.data[kWidgetLineKey], 'مهمتان اليوم');
    expect(store.data.values.join(' ').contains('الطبيبة'), isFalse);
    expect(store.data.keys.toSet(), <String>{kWidgetTitleKey, kWidgetLineKey});
  });

  test('turning it off, or another account being active, clears the line', () async {
    await task('a', 'u1', DateTime(2026, 11, 25, 15));
    final w = make();
    await w.setEnabled('u1', true, 'en', now: now);
    expect(store.data[kWidgetLineKey], '1 task today');
    await w.refresh('u2', 'en', now: now);
    expect(store.data, isEmpty, reason: 'u2 never enabled it');
    await w.setEnabled('u1', true, 'en', now: now);
    await w.setEnabled('u1', false, 'en', now: now);
    expect(store.data, isEmpty);
    expect(await w.enabled('u1'), isFalse);
  });

  test('on an unsupported build or platform nothing is written even if enabled', () async {
    await settings.set(widgetEnabledKey('u1'), '1');
    await make(supported: false).refresh('u1', 'ar', now: now);
    expect(store.data, isEmpty);
    expect(await make(supported: false).enabled('u1'), isFalse);
    expect(WidgetSync.platformSupported, isFalse, reason: 'this build was not made with GLOWARA_WIDGET=true');
  });

  test('logout clears the line', () async {
    WidgetSync.debugSupported = true;
    WidgetSync.debugStore = store;
    addTearDown(() {
      WidgetSync.debugSupported = null;
      WidgetSync.debugStore = null;
    });
    store.data[kWidgetLineKey] = 'x';
    store.data[kWidgetTitleKey] = 'y';
    await WidgetSync.clearForLogout();
    expect(store.data, isEmpty);
  });

  test('the on/off choice is device-only and never exported', () async {
    expect(LocalDatabase.isExportableSetting(widgetEnabledKey('u1')), isFalse);
  });
}
