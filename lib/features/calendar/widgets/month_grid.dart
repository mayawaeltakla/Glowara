/// شبكة الشهر: صف أسماء الأيام ثم 6 أسابيع. العرض فقط، بلا أي كتابة.
library glowara.feature.calendar.month_grid;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/calendar_models.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/features/calendar/calendar_layout.dart';
import 'package:glowara/features/calendar/calendar_style.dart';
import 'package:glowara/features/calendar/widgets/layer_mark.dart';
import 'package:intl/intl.dart';

/// أقصى عدد علامات في الخلية قبل «+».
const int kMaxMarksPerCell = 4;

class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.weekStart,
    required this.locale,
    required this.snapshot,
    required this.selected,
    required this.layer,
    required this.cellHeight,
    required this.onSelect,
  });

  final DateTime month;
  final int weekStart;
  final String locale;
  final MonthSnapshot? snapshot;
  final DateTime selected;

  /// طبقة واحدة للتصفية، أو `null` لكل الطبقات.
  final CalendarLayer? layer;
  final double cellHeight;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final days = monthGridDays(month, weekStart);
    final today = startOfDay(DateTime.now());
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final weekday in weekdayOrder(weekStart))
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Text(
                      DateFormat.E(locale).format(DateTime(2024, 1, weekday)),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var week = 0; week < 6; week++)
          Row(
            children: <Widget>[
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _buildCell(context, days[week * 7 + i], today),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(BuildContext context, DateTime day, DateTime today) {
    final activity = snapshot?.dayFor(day);
    final layers = (activity?.layers ?? const <CalendarLayer>[])
        .where((CalendarLayer l) => layer == null || l == layer)
        .toList();
    final names = layers.map((CalendarLayer l) => context.tr(layerLabelKey(l))).join(', ');
    final label = names.isEmpty
        ? formatFullDate(day, locale)
        : '${formatFullDate(day, locale)}: $names';
    return DayCell(
      day: day,
      inMonth: isInMonth(day, month),
      selected: isSameDay(day, selected),
      isToday: isSameDay(day, today),
      layers: layers,
      height: cellHeight,
      semanticsLabel: label,
      onTap: () => onSelect(day),
    );
  }
}

class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.isToday,
    required this.layers,
    required this.height,
    required this.semanticsLabel,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool isToday;
  final List<CalendarLayer> layers;
  final double height;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final visible = layers.take(kMaxMarksPerCell).toList();
    final extra = layers.length - visible.length;
    final textColor = inMonth ? c.onSurface : c.onSurfaceVariant.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: InkWell(
            key: ValueKey<String>('cal-day-${dateKey(day)}'),
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: selected ? c.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? c.primary
                      : (isToday ? c.gold : Colors.transparent),
                  width: selected || isToday ? 1.8 : 0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected || isToday ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 11,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (final l in visible) LayerMark(layer: l),
                        if (extra > 0)
                          Text(
                            '+',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
