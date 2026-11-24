import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/home_layout.dart';

void main() {
  group('HomeLayout', () {
    test('default is every section visible in canonical order', () {
      expect(HomeLayout.defaults.visibleOrder, kHomeSections);
      expect(HomeLayout.defaults.isDefault, isTrue);
    });

    test('parse is tolerant: bad data gives the default', () {
      for (final raw in <Object?>[null, '', 'not json', '[]', 42, '{"order": 5}']) {
        expect(HomeLayout.parse(raw).visibleOrder, kHomeSections, reason: '$raw');
      }
    });

    test('unknown ids are dropped, duplicates removed, missing sections appended visible', () {
      final l = HomeLayout.parse('{"order":["worship","zzz","worship","tasks"],"hidden":["tasks","nope"]}');
      expect(l.order.take(2), <String>['worship', 'tasks']);
      expect(l.order.toSet(), kHomeSections.toSet());
      expect(l.order.length, kHomeSections.length);
      expect(l.hidden, <String>{'tasks'});
      expect(l.visibleOrder.contains('tasks'), isFalse);
      expect(l.visibleOrder.contains('dayGlow'), isTrue);
    });

    test('move and toggle, with bounds', () {
      var l = HomeLayout.defaults.move('tasks', -1);
      expect(l.order.indexOf('tasks'), kHomeSections.indexOf('tasks') - 1);
      expect(HomeLayout.defaults.move('dayGlow', -1).order, kHomeSections);
      expect(HomeLayout.defaults.move('worship', 1).order, kHomeSections);
      expect(HomeLayout.defaults.move('unknown', 1).order, kHomeSections);
      l = l.toggle('mood');
      expect(l.hidden, <String>{'mood'});
      expect(l.toggle('mood').hidden, isEmpty);
      expect(l.isDefault, isFalse);
    });

    test('storage round-trips', () {
      final l = HomeLayout.defaults.move('habits', -2).toggle('worship');
      final back = HomeLayout.parse(l.toStorage());
      expect(back.order, l.order);
      expect(back.hidden, l.hidden);
    });

    test('the layout preference is not exported', () {
      expect(LocalDatabase.isExportableSetting(homeLayoutKey('u1')), isFalse);
      expect(LocalDatabase.isExportableSetting('water_goal_ml'), isTrue);
    });
  });
}
