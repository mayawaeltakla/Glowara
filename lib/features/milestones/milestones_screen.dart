/// معالمي: ما تحقق من سجلاتها الحقيقية، بصيغة هادئة.
///
/// بلا نقاط ولا مستويات ولا ترتيب ولا مقارنة. لا عبادات ولا مزاج ولا مذكرات.
/// المعلم يبقى مسجّلًا ولا يُسحب. الشاشة تكتب سجلات المعالم فقط.
library glowara.feature.milestones;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/milestone_models.dart';
import 'package:glowara/core/repositories/milestone_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:intl/intl.dart';

class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen({super.key});

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  bool _didLoad = false;
  bool _loading = true;
  Object? _error;
  List<MilestoneEntry> _entries = <MilestoneEntry>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await MilestoneRepository(state.db, state.progress).evaluate(state.userId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  String _categoryKey(MilestoneCategory c) {
    switch (c) {
      case MilestoneCategory.start:
        return 'msCatStart';
      case MilestoneCategory.consistency:
        return 'msCatConsistency';
      case MilestoneCategory.study:
        return 'msCatStudy';
      case MilestoneCategory.care:
        return 'msCatCare';
      case MilestoneCategory.goals:
        return 'msCatGoals';
    }
  }

  IconData _categoryIcon(MilestoneCategory c) {
    switch (c) {
      case MilestoneCategory.start:
        return Icons.wb_sunny_outlined;
      case MilestoneCategory.consistency:
        return Icons.event_available_outlined;
      case MilestoneCategory.study:
        return Icons.menu_book_outlined;
      case MilestoneCategory.care:
        return Icons.spa_outlined;
      case MilestoneCategory.goals:
        return Icons.track_changes;
    }
  }

  String _unitKey(MilestoneMetric m) {
    switch (m) {
      case MilestoneMetric.tasksDone:
        return 'msUnitTasks';
      case MilestoneMetric.habitLogs:
        return 'msUnitHabits';
      case MilestoneMetric.studySessions:
        return 'msUnitSessions';
      case MilestoneMetric.careDone:
        return 'msUnitCare';
      case MilestoneMetric.goalsCreated:
      case MilestoneMetric.goalsCompleted:
        return 'msUnitGoals';
      case MilestoneMetric.activeDays:
        return 'msUnitDays';
      case MilestoneMetric.studyMinutes:
        return 'msUnitMinutes';
    }
  }

  /// أقرب معلم لم يتحقق في كل فئة (بترتيب الكتالوج).
  List<MilestoneEntry> _upNext() {
    final result = <MilestoneEntry>[];
    for (final category in MilestoneCategory.values) {
      for (final e in _entries) {
        if (e.def.category == category && !e.earned) {
          result.add(e);
          break;
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final earned = _entries.where((e) => e.earned).toList();
    final upNext = _upNext();

    return GlowPage(
      title: context.tr('msTitle'),
      child: _error != null
          ? GlowErrorView(message: context.tr('msLoadError'), onRetry: _load)
          : ListView(
              children: <Widget>[
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.tr('msNote'),
                    key: const Key('ms-note'),
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.6),
                  ),
                ),
                if (!_loading && earned.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      context.tr('msEmpty'),
                      key: const Key('ms-empty'),
                      style: TextStyle(color: c.onSurface, fontSize: 14, height: 1.6),
                    ),
                  ),
                if (earned.isNotEmpty) ...<Widget>[
                  GlowSectionTitle(title: context.tr('msEarnedHeader')),
                  for (final e in earned) _earnedRow(e, c),
                  const SizedBox(height: 12),
                ],
                if (upNext.isNotEmpty) ...<Widget>[
                  GlowSectionTitle(title: context.tr('msNextHeader')),
                  for (final e in upNext) _nextRow(e, c),
                ],
              ],
            ),
    );
  }

  Widget _earnedRow(MilestoneEntry e, GlowColors c) {
    final locale = AppState.of(context).locale;
    final date = DateFormat.yMMMd(locale).format(e.earnedAt!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlowCard(
        key: Key('ms-earned-${e.def.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(_categoryIcon(e.def.category), color: c.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          context.tr(e.def.titleKey),
                          style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                        ),
                      ),
                      if (e.isNew) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          key: Key('ms-new-${e.def.id}'),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.primaryContainer,
                            borderRadius: BorderRadius.circular(GlowRadius.pill),
                          ),
                          child: Text(
                            context.tr('msNew'),
                            style: TextStyle(fontSize: 11, color: c.onSurface),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(e.def.bodyKey),
                    style: TextStyle(fontSize: 13, color: c.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${context.tr('msRecordedOn')} $date',
                    style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nextRow(MilestoneEntry e, GlowColors c) {
    final threshold = e.def.threshold;
    final current = e.current < threshold ? e.current : threshold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlowCard(
        key: Key('ms-next-${e.def.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.radio_button_unchecked, color: c.onSurfaceVariant, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${context.tr(_categoryKey(e.def.category))} · ${context.tr(e.def.titleKey)}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(e.def.bodyKey),
                    style: TextStyle(fontSize: 13, color: c.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$current ${context.tr('of')} $threshold ${context.tr(_unitKey(e.def.metric))}',
                    key: Key('ms-progress-${e.def.id}'),
                    style: TextStyle(fontSize: 12, color: c.onSurface),
                  ),
                  const SizedBox(height: 4),
                  GlowProgress(value: threshold == 0 ? 0 : current / threshold, height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
