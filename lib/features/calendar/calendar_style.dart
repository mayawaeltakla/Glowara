/// ألوان وأشكال علامات التقويم، مشتقة من رموز الثيم الحالية (لا ألوان جديدة).
library glowara.feature.calendar.style;

import 'package:flutter/material.dart';
import 'package:glowara/core/models/calendar_models.dart';
import 'package:glowara/core/theme/glow_theme.dart';

/// لون العلامة: لون الثيم مُغمَّق نحو لون النص بنسبة ثابتة ليبلغ تباينه عن سطح
/// البطاقة 3:1 على الأقل (حدّ WCAG للعناصر غير النصية) في كل الثيمات والوضعين.
/// يتحقق من ذلك `test/calendar_style_test.dart`.
Color layerColor(GlowColors c, CalendarLayer layer) {
  final base = switch (layer) {
    CalendarLayer.tasks => c.primary,
    CalendarLayer.study => c.gold,
    CalendarLayer.habits => c.lilac,
    CalendarLayer.worship => c.success,
    CalendarLayer.care => c.blush,
    CalendarLayer.nutrition => Color.lerp(c.success, c.gold, 0.5)!,
  };
  return Color.lerp(base, c.onSurface, 0.45)!;
}

/// شكل العلامة (يضاف إلى اللون لأن اللون وحده لا يكفي للتمييز).
enum LayerShape { circle, diamond, ring, dot, square, triangle }

LayerShape layerShape(CalendarLayer layer) => switch (layer) {
      CalendarLayer.tasks => LayerShape.circle,
      CalendarLayer.study => LayerShape.diamond,
      CalendarLayer.habits => LayerShape.ring,
      CalendarLayer.worship => LayerShape.dot,
      CalendarLayer.care => LayerShape.square,
      CalendarLayer.nutrition => LayerShape.triangle,
    };

IconData layerIcon(CalendarLayer layer) => switch (layer) {
      CalendarLayer.tasks => Icons.task_alt,
      CalendarLayer.study => Icons.menu_book,
      CalendarLayer.habits => Icons.emoji_objects_outlined,
      CalendarLayer.worship => Icons.mosque_outlined,
      CalendarLayer.care => Icons.spa_outlined,
      CalendarLayer.nutrition => Icons.restaurant_outlined,
    };

/// مفتاح نص اسم الطبقة.
String layerLabelKey(CalendarLayer layer) => switch (layer) {
      CalendarLayer.tasks => 'calLayerTasks',
      CalendarLayer.study => 'calLayerStudy',
      CalendarLayer.habits => 'calLayerHabits',
      CalendarLayer.worship => 'calLayerWorship',
      CalendarLayer.care => 'calLayerCare',
      CalendarLayer.nutrition => 'calLayerNutrition',
    };

/// المسار في التطبيق للقسم الأصلي لهذه الطبقة.
String layerRoute(CalendarLayer layer) => switch (layer) {
      CalendarLayer.tasks => '/tasks',
      CalendarLayer.study => '/study',
      CalendarLayer.habits => '/habits',
      CalendarLayer.worship => '/worship',
      CalendarLayer.care => '/care',
      CalendarLayer.nutrition => '/health',
    };
