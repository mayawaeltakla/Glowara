/// تخطيط الصفحة الرئيسية: ترتيب الأقسام وأيّها ظاهر. تفضيل شكلي على هذا الجهاز
/// فقط (لا يُصدَّر). المهام والعادات وغيرها تبقى محفوظة سواء أُخفي قسمها أم لا.
library glowara.models.home_layout;

import 'dart:convert';

/// أقسام الرئيسية القابلة للترتيب والإخفاء، بترتيبها الافتراضي.
const List<String> kHomeSections = <String>[
  'dayGlow',
  'water',
  'corners',
  'mood',
  'tasks',
  'habits',
  'worship',
];

/// مفتاح التخزين في الإعدادات (بادئة `home_layout_` لا تُصدَّر).
String homeLayoutKey(String userId) => 'home_layout_$userId';

class HomeLayout {
  const HomeLayout({required this.order, this.hidden = const <String>{}});

  final List<String> order;
  final Set<String> hidden;

  static const HomeLayout defaults = HomeLayout(order: kHomeSections);

  List<String> get visibleOrder => order.where((id) => !hidden.contains(id)).toList();

  bool get isDefault =>
      hidden.isEmpty && order.length == kHomeSections.length && List<String>.generate(order.length, (i) => order[i]).join(',') == kHomeSections.join(',');

  /// يقرأ التخزين بتسامح: أي خلل يعيد الافتراضي، وأقسام مجهولة تُهمل، وأقسام
  /// جديدة غير مذكورة تُضاف ظاهرة في آخر القائمة.
  static HomeLayout parse(Object? raw) {
    if (raw is! String || raw.isEmpty) return defaults;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return defaults;
      final order = <String>[];
      final o = j['order'];
      if (o is List) {
        for (final id in o) {
          if (id is String && kHomeSections.contains(id) && !order.contains(id)) order.add(id);
        }
      }
      for (final id in kHomeSections) {
        if (!order.contains(id)) order.add(id);
      }
      final hidden = <String>{};
      final h = j['hidden'];
      if (h is List) {
        for (final id in h) {
          if (id is String && kHomeSections.contains(id)) hidden.add(id);
        }
      }
      return HomeLayout(order: order, hidden: hidden);
    } catch (_) {
      return defaults;
    }
  }

  String toStorage() => jsonEncode(<String, Object?>{'order': order, 'hidden': hidden.toList()..sort()});

  /// يحرّك قسمًا موضعًا واحدًا (-1 أعلى، +1 أسفل). خارج الحدود لا يغيّر شيئًا.
  HomeLayout move(String id, int delta) {
    final i = order.indexOf(id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= order.length) return this;
    final next = List<String>.of(order);
    final item = next.removeAt(i);
    next.insert(j, item);
    return HomeLayout(order: next, hidden: hidden);
  }

  HomeLayout toggle(String id) {
    if (!order.contains(id)) return this;
    final next = Set<String>.of(hidden);
    if (!next.remove(id)) next.add(id);
    return HomeLayout(order: order, hidden: next);
  }
}
