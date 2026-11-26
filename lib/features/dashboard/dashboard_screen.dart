/// ملخص حياتك: بطاقات هادئة من أقسام متعددة، كل بطاقة تفتح قسمها. بلا مجموع
/// حياة ولا درجة ولا نسبة. لا مزاج ولا مذكرات ولا عبادة ولا ركني الصغير.
library glowara.feature.dashboard;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/dashboard_models.dart';
import 'package:glowara/core/repositories/dashboard_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/calendar/calendar_layout.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.today});

  /// لليوم المعروض؛ الافتراضي اليوم الفعلي (للاختبار).
  final DateTime? today;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _didLoad = false;
  bool _loading = true;
  Object? _error;
  LifestyleSummary _summary = const LifestyleSummary();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    final today = widget.today ?? DateTime.now();
    final start = weekStartOf(today, weekStartFor(state.locale));
    try {
      final s = await DashboardRepository(state.db).build(
        state.userId,
        today: today,
        weekStart: start,
        weekEnd: weekEndOf(start),
      );
      if (!mounted) return;
      setState(() {
        _summary = s;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final locale = AppState.of(context).locale;
    final s = _summary;
    return GlowPage(
      title: context.tr('dbTitle'),
      child: _error != null
          ? GlowErrorView(message: context.tr('dbLoadError'), onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: <Widget>[
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  Text(
                    context.tr('dbNote'),
                    key: const Key('db-note'),
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  if (!_loading && s.isEmpty)
                    Text(context.tr('dbEmpty'), key: const Key('db-empty'), style: TextStyle(color: c.onSurfaceVariant)),
                  if (s.upcomingTasks.isNotEmpty)
                    _card('tasks', 'dbTasks', '/tasks', c, <Widget>[
                      for (final t in s.upcomingTasks)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('${t.title} · ${formatShortDate(t.dueDateTime!, locale)} ${formatTime(t.dueDateTime!, locale)}'),
                        ),
                    ]),
                  if (s.studyMinutesWeek > 0)
                    _card('study', 'dbStudy', '/study', c, <Widget>[
                      Text(
                        context.tr('dbStudyLine').replaceAll('{m}', '${s.studyMinutesWeek}'),
                        key: const Key('db-study-line'),
                      ),
                    ]),
                  if (s.habitsScheduled > 0)
                    _card('habits', 'dbHabits', '/habits', c, <Widget>[
                      Text(
                        context.tr('dbHabitsLine').replaceAll('{d}', '${s.habitsDone}').replaceAll('{n}', '${s.habitsScheduled}'),
                        key: const Key('db-habits-line'),
                      ),
                    ]),
                  if (s.routinesToday.isNotEmpty)
                    _card('routines', 'dbRoutines', '/routines', c, <Widget>[
                      for (final r in s.routinesToday)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${r.routine.name} · ${context.tr('dbStepsLine').replaceAll('{d}', '${r.stepsDone}').replaceAll('{n}', '${r.routine.steps.length}')}',
                          ),
                        ),
                    ]),
                  if (s.waterMl > 0)
                    _card('water', 'dbWater', '/health', c, <Widget>[
                      Text(
                        '${s.waterMl} ${context.tr('mlShort')}',
                        key: const Key('db-water-line'),
                      ),
                    ]),
                  if (s.dreamsInProgress.isNotEmpty)
                    _card('dreams', 'dbDreams', '/dreams', c, <Widget>[
                      for (final d in s.dreamsInProgress)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            d.steps.isEmpty
                                ? d.title
                                : '${d.title} · ${context.tr('drStepsCount').replaceAll('{d}', '${d.stepsDone}').replaceAll('{t}', '${d.steps.length}')}',
                          ),
                        ),
                    ]),
                  if (s.booksReading.isNotEmpty)
                    _card('books', 'dbBooks', '/library', c, <Widget>[
                      for (final b in s.booksReading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(b.currentPage > 0
                              ? '${b.title} · ${context.tr('lbPageAt').replaceAll('{c}', '${b.currentPage}')}'
                              : b.title),
                        ),
                    ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _card(String id, String titleKey, String route, GlowColors c, List<Widget> children) {
    return GlowCard(
      key: Key('db-card-$id'),
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => _open(route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(context.tr(titleKey), style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface))),
              Icon(Icons.chevron_right, size: 18, color: c.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}
