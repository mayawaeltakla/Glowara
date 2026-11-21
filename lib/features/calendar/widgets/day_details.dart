/// تفاصيل يوم في التقويم. قراءة فقط: لا تبديل حالة ولا إنشاء سجلات؛ كل ما
/// يمكن فعله هو الانتقال إلى القسم الأصلي.
library glowara.feature.calendar.day_details;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/calendar_models.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/calendar/calendar_style.dart';
import 'package:glowara/features/calendar/widgets/layer_mark.dart';

class DayDetails extends StatelessWidget {
  const DayDetails({
    super.key,
    required this.day,
    required this.locale,
    required this.activity,
    required this.subjectNames,
    required this.layer,
    required this.onOpen,
  });

  final DateTime day;
  final String locale;
  final DayActivity activity;
  final Map<String, String> subjectNames;

  /// طبقة واحدة للتصفية، أو `null` لكل الطبقات.
  final CalendarLayer? layer;

  /// يُستدعى بمسار القسم الأصلي.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final shown = CalendarLayer.values
        .where((CalendarLayer l) => activity.layers.contains(l) && (layer == null || layer == l))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          formatFullDate(day, locale),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.onSurface),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: <Widget>[
                  Icon(Icons.spa_outlined, size: 32, color: c.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('calEmptyDay'),
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          for (final l in shown) _section(context, l),
      ],
    );
  }

  Widget _section(BuildContext context, CalendarLayer l) {
    final c = context.glowColors;
    final route = l == CalendarLayer.tasks ? '/tasks?day=${dateKey(day)}' : layerRoute(l);
    return GlowCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              LayerMark(layer: l, size: 9),
              const SizedBox(width: 8),
              Icon(layerIcon(l), size: 18, color: c.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr(layerLabelKey(l)),
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                ),
              ),
              TextButton(
                onPressed: () => onOpen(route),
                child: Text(context.tr('calOpenSection')),
              ),
            ],
          ),
          ..._rows(context, l),
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context, CalendarLayer l) {
    switch (l) {
      case CalendarLayer.tasks:
        return <Widget>[
          for (final t in activity.tasks)
            _Line(
              icon: t.done ? Icons.check_circle : Icons.radio_button_unchecked,
              iconColor: t.done ? context.glowColors.success : context.glowColors.onSurfaceVariant,
              text: t.title,
              trailing: t.time == null ? null : formatTime(t.time!, locale),
            ),
        ];
      case CalendarLayer.study:
        return <Widget>[
          for (final e in activity.studyMinutesBySubject.entries)
            _Line(
              icon: Icons.menu_book_outlined,
              text: subjectNames[e.key] ?? context.tr('calUnknownSubject'),
              trailing: '${e.value} ${context.tr('minutesLabel')}',
            ),
        ];
      case CalendarLayer.habits:
        return <Widget>[
          for (final h in activity.habits)
            _Line(
              icon: h.logged ? Icons.check_circle_outline : Icons.schedule,
              text: h.name,
              trailing: h.logged ? context.tr('calHabitLogged') : context.tr('calHabitPlanned'),
            ),
        ];
      case CalendarLayer.worship:
        return <Widget>[
          if (activity.prayers) _Line(icon: Icons.circle, small: true, text: context.tr('calWorshipPrayers')),
          if (activity.quran) _Line(icon: Icons.circle, small: true, text: context.tr('calWorshipQuran')),
          if (activity.adhkar) _Line(icon: Icons.circle, small: true, text: context.tr('calWorshipAdhkar')),
          if (activity.otherWorship) _Line(icon: Icons.circle, small: true, text: context.tr('calWorshipOther')),
        ];
      case CalendarLayer.care:
        return <Widget>[
          for (final title in activity.care) _Line(icon: Icons.spa_outlined, text: title),
        ];
      case CalendarLayer.nutrition:
        return <Widget>[
          for (final m in activity.meals)
            _Line(
              icon: m.hasNote ? Icons.notes : Icons.restaurant_outlined,
              text: _mealLabel(context, m.mealType),
              semanticsSuffix: m.hasNote ? context.tr('calHasNote') : null,
            ),
          if (activity.waterMl > 0)
            _Line(
              icon: Icons.water_drop_outlined,
              text: '${activity.waterMl} ${context.tr('mlShort')}',
            ),
        ];
    }
  }

  String _mealLabel(BuildContext context, String type) {
    switch (type) {
      case 'breakfast':
        return context.tr('breakfast');
      case 'lunch':
        return context.tr('lunch');
      case 'dinner':
        return context.tr('dinner');
      case 'snack':
        return context.tr('snack');
      default:
        return context.tr('otherMeal');
    }
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.text,
    this.iconColor,
    this.trailing,
    this.small = false,
    this.semanticsSuffix,
  });

  final IconData icon;
  final String text;
  final Color? iconColor;
  final String? trailing;
  final bool small;
  final String? semanticsSuffix;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final line = Padding(
      padding: const EdgeInsets.only(top: 8, right: 6, left: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: small ? 8 : 18, color: iconColor ?? c.onSurfaceVariant),
          SizedBox(width: small ? 12 : 8),
          Expanded(child: Text(text, style: TextStyle(color: c.onSurface))),
          if (trailing != null)
            Text(trailing!, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
        ],
      ),
    );
    if (semanticsSuffix == null) return line;
    return Semantics(label: '$text, $semanticsSuffix', child: ExcludeSemantics(child: line));
  }
}
