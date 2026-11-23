/// التغذية المتوازنة: خطة وجبات الأسبوع وملخص هادئ لما سجّلتِه.
///
/// بلا سعرات ولا أهداف وزن ولا درجات. الاقتراحات عامة للإلهام وتُملأ بطلبها فقط.
/// تكتب سجلات خطة الوجبات وحدها.
library glowara.feature.nutrition;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/nutrition_models.dart';
import 'package:glowara/core/repositories/nutrition_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/calendar/calendar_layout.dart';
import 'package:intl/intl.dart' show DateFormat;

/// أبعد أسبوع يمكن التخطيط له (بالأسابيع بعد الأسبوع الحالي).
const int kMaxPlanWeeksAhead = 8;

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key, this.initialWeekStart});

  final DateTime? initialWeekStart;

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  bool _didLoad = false;
  bool _loading = true;
  Object? _error;

  late DateTime _weekStart;
  MealPlan? _plan;
  NutritionWeekSummary _summary = const NutritionWeekSummary();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    final first = weekStartFor(AppState.of(context).locale);
    _weekStart = weekStartOf(widget.initialWeekStart ?? DateTime.now(), first);
    _load();
  }

  NutritionRepository _repo(AppState state) => NutritionRepository(state.db);

  DateTime get _currentWeekStart => weekStartOf(DateTime.now(), weekStartFor(AppState.of(context).locale));

  Future<void> _load() async {
    final state = AppState.of(context);
    final start = _weekStart;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = _repo(state);
      final plan = await repo.planFor(state.userId, start);
      final summary = await repo.summary(state.userId, start, weekEndOf(start));
      if (!mounted || !_weekStart.isAtSameMomentAs(start)) return;
      setState(() {
        _plan = plan;
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  bool get _canGoNext =>
      _weekStart.isBefore(addDays(_currentWeekStart, 7 * kMaxPlanWeeksAhead));

  void _goTo(DateTime weekStart) {
    setState(() => _weekStart = weekStart);
    _load();
  }

  Future<void> _editCell(DateTime day, String mealType) async {
    final state = AppState.of(context);
    final key = dateKey(day);
    final current = _plan?.cell(key, mealType) ?? '';
    final controller = TextEditingController(text: current);
    final ideas = kMealIdeas.where((i) => i.mealType == mealType).toList();
    final locale = state.locale;

    // null = إلغاء، وأي نص (حتى الفارغ) = حفظ.
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('${context.tr(mealType)} · ${context.tr('ntEditTitle')}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                key: const Key('nt-edit-field'),
                controller: controller,
                maxLength: kPlanCellMax,
                maxLines: 2,
                decoration: InputDecoration(hintText: context.tr('ntCellHint'), counterText: ''),
              ),
              const SizedBox(height: 8),
              Text(context.tr('ntIdeas'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final idea in ideas)
                    ActionChip(
                      key: Key('nt-idea-${idea.id}'),
                      label: Text(idea.text(locale)),
                      onPressed: () => controller.text = idea.text(locale),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('nt-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('cancel')),
          ),
          if (current.isNotEmpty)
            TextButton(
              key: const Key('nt-clear'),
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: Text(context.tr('ntClear')),
            ),
          FilledButton(
            key: const Key('nt-save'),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    await _repo(state).setCell(
      userId: state.userId,
      weekStart: _weekStart,
      weekEnd: weekEndOf(_weekStart),
      day: key,
      mealType: mealType,
      text: result,
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final c = context.glowColors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final locale = state.locale;
    final range = '${formatShortDate(_weekStart, locale)} – ${formatShortDate(weekEndOf(_weekStart), locale)}';
    final showSummary = !_weekStart.isAfter(_currentWeekStart);

    return GlowPage(
      title: context.tr('ntTitle'),
      child: _error != null
          ? GlowErrorView(message: context.tr('ntLoadError'), onRetry: _load)
          : ListView(
              children: <Widget>[
                GlowCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        key: const Key('nt-prev'),
                        onPressed: () => _goTo(addDays(_weekStart, -7)),
                        icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left),
                        tooltip: context.tr('ntPrevWeek'),
                      ),
                      Expanded(
                        child: Text(
                          range,
                          key: const Key('nt-range'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.onSurface),
                        ),
                      ),
                      IconButton(
                        key: const Key('nt-next'),
                        onPressed: _canGoNext ? () => _goTo(addDays(_weekStart, 7)) : null,
                        icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right),
                        tooltip: context.tr('ntNextWeek'),
                      ),
                    ],
                  ),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 8),
                Text(
                  context.tr('ntNote'),
                  key: const Key('nt-note'),
                  style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 12),
                if (showSummary) ...<Widget>[
                  _summaryCard(c),
                  const SizedBox(height: 12),
                ],
                GlowSectionTitle(title: context.tr('ntPlanTitle')),
                for (var i = 0; i < 7; i++) _dayCard(addDays(_weekStart, i), c, locale),
              ],
            ),
    );
  }

  Widget _summaryCard(GlowColors c) {
    final s = _summary;
    return GlowCard(
      key: const Key('nt-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.tr('ntSummaryTitle'),
            style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
          ),
          const SizedBox(height: 8),
          if (s.isEmpty)
            Text(context.tr('ntSummaryEmpty'), style: TextStyle(color: c.onSurfaceVariant, fontSize: 13))
          else ...<Widget>[
            if (s.daysWithMeals > 0)
              Text(
                '${context.tr('ntDaysWithMeals')}: ${s.daysWithMeals}',
                style: TextStyle(color: c.onSurface, fontSize: 14),
              ),
            if (s.waterDays > 0)
              Text(
                '${context.tr('ntWaterDays')}: ${s.waterDays}',
                style: TextStyle(color: c.onSurface, fontSize: 14),
              ),
            if (s.groupsSeen.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(context.tr('ntGroupsSeen'), style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final g in kFoodGroups.where(s.groupsSeen.contains))
                    Chip(
                      key: Key('nt-group-$g'),
                      label: Text(context.tr(kFoodGroupLabelKeys[g]!)),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _dayCard(DateTime day, GlowColors c, String locale) {
    final key = dateKey(day);
    final title = '${DateFormat.EEEE(locale).format(day)} · ${formatShortDate(day, locale)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlowCard(
        key: Key('nt-day-$key'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
            const SizedBox(height: 4),
            for (final type in kPlanMealTypes)
              InkWell(
                key: Key('nt-cell-$key-$type'),
                onTap: () => _editCell(day, type),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 76,
                        child: Text(
                          context.tr(type),
                          style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _plan?.cell(key, type) ?? '+ ${context.tr('ntAddCell')}',
                          style: TextStyle(
                            color: _plan?.cell(key, type) == null ? c.onSurfaceVariant : c.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
