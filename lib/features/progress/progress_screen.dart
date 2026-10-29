/// التقدم والإنجازات: إحصاءات حقيقية وأهداف شهرية.
library glowara.feature.progress;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/repositories/study_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _didLoad = false;
  bool _loading = true;
  int _period = 0;

  PeriodStats _stats = const PeriodStats();
  PeriodStats _monthStats = const PeriodStats();
  int _averageWater = 0;
  List<StudySubject> _subjects = <StudySubject>[];
  Map<String, StudyProgress> _subjectProgress = <String, StudyProgress>{};
  List<MonthlyGoal> _goals = <MonthlyGoal>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  DateTime _from() {
    final now = DateTime.now();
    switch (_period) {
      case 1:
        return startOfWeek(now);
      case 2:
        return startOfMonth(now);
      default:
        return now;
    }
  }

  DateTime _to() {
    final now = DateTime.now();
    switch (_period) {
      case 1:
        return endOfWeek(now);
      case 2:
        return endOfMonth(now);
      default:
        return now;
    }
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    final now = DateTime.now();
    final from = _from();
    final to = _to();
    final stats = await state.progress.stats(userId: state.userId, from: from, to: to);
    final monthStats = await state.progress.stats(
      userId: state.userId,
      from: startOfMonth(now),
      to: endOfMonth(now),
    );
    final subjects = await state.study.subjects(state.userId);
    final progress = await state.progress.subjectProgress(state.userId);
    final goals = await state.progress.goals(state.userId, monthKey(now));
    final average = await state.progress.averageWater(state.userId, from, to);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _monthStats = monthStats;
      _subjects = subjects;
      _subjectProgress = progress;
      _goals = goals;
      _averageWater = average;
      _loading = false;
    });
  }

  String _metricLabel(BuildContext context, String metric) {
    switch (metric) {
      case 'tasks':
        return context.tr('metricTasks');
      case 'studyMinutes':
        return context.tr('metricStudy');
      case 'quranDays':
        return context.tr('metricQuran');
      case 'waterDays':
        return context.tr('metricWater');
      case 'lessons':
        return context.tr('metricLessons');
      case 'habitDays':
        return context.tr('metricHabits');
      default:
        return metric;
    }
  }

  String _encouragement(BuildContext context) {
    if (!_stats.hasData) return context.tr('encouragementZero');
    final rates = <double>[
      if (_stats.tasksTotal > 0) _stats.taskRate,
      if (_stats.habitsScheduled > 0) _stats.habitRate,
    ];
    if (rates.isEmpty) return context.tr('encouragementSome');
    final average = rates.reduce((a, b) => a + b) / rates.length;
    if (average >= 0.8) return context.tr('encouragementGreat');
    if (average >= 0.5) return context.tr('encouragementGood');
    return context.tr('encouragementSome');
  }

  Future<void> _openGoalEditor({MonthlyGoal? goal}) async {
    final state = AppState.of(context);
    final result = await showDialog<MonthlyGoal>(
      context: context,
      builder: (_) => _GoalDialog(
        userId: state.userId,
        month: monthKey(DateTime.now()),
        goal: goal,
      ),
    );
    if (result == null || !mounted) return;
    await state.progress.saveGoal(result);
    if (mounted) _load();
  }

  Future<void> _deleteGoal(MonthlyGoal goal) async {
    final ok = await showConfirmDialog(context, title: context.tr('deleteGoalConfirm'));
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.progress.deleteGoal(goal.id);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final state = AppState.of(context);

    return GlowPage(
      title: context.tr('progress'),
      actions: <Widget>[
        IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: <Widget>[
                Text(
                  context.tr('progressSub'),
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    GlowChoiceChip(
                      label: context.tr('todayTab'),
                      selected: _period == 0,
                      onTap: () {
                        setState(() => _period = 0);
                        _load();
                      },
                    ),
                    GlowChoiceChip(
                      label: context.tr('weekTab'),
                      selected: _period == 1,
                      onTap: () {
                        setState(() => _period = 1);
                        _load();
                      },
                    ),
                    GlowChoiceChip(
                      label: context.tr('monthTab'),
                      selected: _period == 2,
                      onTap: () {
                        setState(() => _period = 2);
                        _load();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_stats.hasData)
                  GlowCard(
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.insights, color: c.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                context.tr('noDataYet'),
                                style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                              ),
                              Text(
                                context.tr('noDataYetSub'),
                                style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else ...<Widget>[
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.65,
                    children: <Widget>[
                      GlowStatTile(
                        label: context.tr('tasksCompleted'),
                        value: '${_stats.tasksDone}/${_stats.tasksTotal}',
                        icon: Icons.task_alt,
                      ),
                      GlowStatTile(
                        label: context.tr('habitsCompleted'),
                        value: '${_stats.habitsDone}/${_stats.habitsScheduled}',
                        icon: Icons.emoji_objects,
                        accent: c.gold,
                      ),
                      GlowStatTile(
                        label: context.tr('studyMinutesLabel'),
                        value: '${_stats.studyMinutes}',
                        icon: Icons.timer_outlined,
                      ),
                      GlowStatTile(
                        label: context.tr('quranDays'),
                        value: '${_stats.quranDays}',
                        icon: Icons.menu_book,
                        accent: c.gold,
                      ),
                      GlowStatTile(
                        label: context.tr('waterAverage'),
                        value: '$_averageWater ${context.tr('mlShort')}',
                        icon: Icons.water_drop,
                      ),
                      GlowStatTile(
                        label: context.tr('journalDays'),
                        value: '${_stats.journalEntries}',
                        icon: Icons.edit_note,
                        accent: c.gold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GlowCard(
                    child: Column(
                      children: <Widget>[
                        GlowLabeledProgress(
                          label: context.tr('taskRate'),
                          value: _stats.taskRate,
                          trailing: '${_stats.tasksDone}/${_stats.tasksTotal}',
                        ),
                        const SizedBox(height: 10),
                        GlowLabeledProgress(
                          label: context.tr('habitRate'),
                          value: _stats.habitRate,
                          trailing: '${_stats.habitsDone}/${_stats.habitsScheduled}',
                        ),
                        if (_stats.careStepsTotal > 0) ...<Widget>[
                          const SizedBox(height: 10),
                          GlowLabeledProgress(
                            label: context.tr('careRate'),
                            value: _stats.careRate,
                            trailing: '${_stats.careStepsDone}/${_stats.careStepsTotal}',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (state.display.showMotivation)
                    GlowCard(
                      gradient: c.heroGradient,
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.favorite, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _encouragement(context),
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                GlowSectionTitle(title: context.tr('studyBySubject'), icon: Icons.menu_book),
                if (_subjects.isEmpty)
                  GlowCard(
                    child: Text(
                      context.tr('noSubjectsSub'),
                      style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant),
                    ),
                  )
                else
                  GlowCard(
                    child: Column(
                      children: _subjects.map((subject) {
                        final progress = _subjectProgress[subject.id] ??
                            const StudyProgress(done: 0, total: 0);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlowLabeledProgress(
                            label: subject.name,
                            value: progress.ratio,
                            trailing: '${progress.done}/${progress.total}',
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                GlowSectionTitle(
                  title: context.tr('goalsTitle'),
                  icon: Icons.flag,
                  actionLabel: context.tr('addGoal'),
                  onAction: () => _openGoalEditor(),
                ),
                if (_goals.isEmpty)
                  GlowEmptyState(
                    icon: Icons.flag_outlined,
                    title: context.tr('noGoals'),
                    subtitle: context.tr('noGoalsSub'),
                    actionLabel: context.tr('addGoal'),
                    onAction: () => _openGoalEditor(),
                  )
                else
                  ..._goals.map((goal) {
                    final value = AppState.of(context).progress.goalValue(goal, _monthStats);
                    final ratio = goal.target == 0 ? 0.0 : (value / goal.target).clamp(0.0, 1.0).toDouble();
                    return GlowCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  goal.title,
                                  style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                                ),
                              ),
                              if (ratio >= 1)
                                Icon(Icons.emoji_events, color: c.gold, size: 18),
                              IconButton(
                                onPressed: () => _openGoalEditor(goal: goal),
                                icon: Icon(Icons.edit_outlined, size: 17, color: c.onSurfaceVariant),
                              ),
                              IconButton(
                                onPressed: () => _deleteGoal(goal),
                                icon: Icon(Icons.delete_outline, size: 17, color: c.onSurfaceVariant),
                              ),
                            ],
                          ),
                          Text(
                            '${_metricLabel(context, goal.metric)} • $value ${context.tr('goalOfTarget')} ${goal.target}',
                            style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          GlowProgress(value: ratio),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.userId, required this.month, this.goal});

  final String userId;
  final String month;
  final MonthlyGoal? goal;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  late String _metric;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.goal?.title ?? '');
    _target = TextEditingController(text: widget.goal?.target.toString() ?? '10');
    _metric = widget.goal?.metric ?? 'tasks';
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.goal == null ? context.tr('addGoal') : l10n.edit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _title,
              autofocus: widget.goal == null,
              decoration: InputDecoration(labelText: context.tr('goalTitle')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _metric,
              decoration: InputDecoration(labelText: context.tr('goalMetric')),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'tasks', child: Text(context.tr('metricTasks'))),
                DropdownMenuItem<String>(value: 'studyMinutes', child: Text(context.tr('metricStudy'))),
                DropdownMenuItem<String>(value: 'quranDays', child: Text(context.tr('metricQuran'))),
                DropdownMenuItem<String>(value: 'waterDays', child: Text(context.tr('metricWater'))),
                DropdownMenuItem<String>(value: 'lessons', child: Text(context.tr('metricLessons'))),
                DropdownMenuItem<String>(value: 'habitDays', child: Text(context.tr('metricHabits'))),
              ],
              onChanged: (value) => setState(() => _metric = value ?? 'tasks'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('goalTarget')),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            final target = int.tryParse(_target.text.trim()) ?? 0;
            if (title.isEmpty || target <= 0) return;
            final existing = widget.goal;
            Navigator.of(context).pop(
              MonthlyGoal(
                id: existing?.id ?? uniqueId(),
                userId: widget.userId,
                month: widget.month,
                title: title,
                metric: _metric,
                target: target,
                createdAt: existing?.createdAt ?? DateTime.now(),
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
