/// شاشة "اليوم": ملخص حقيقي للمهام والعادات والماء والدراسة والمزاج.
library glowara.feature.home;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didLoad = false;
  bool _loading = true;

  List<TaskItem> _tasks = <TaskItem>[];
  List<Habit> _habits = <Habit>[];
  Set<String> _doneHabits = <String>{};
  int _waterMl = 0;
  int _studyMinutes = 0;
  MoodEntry? _mood;
  String? _lastSurah;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    final uid = state.userId;
    final now = DateTime.now();
    final results = await Future.wait<Object?>(<Future<Object?>>[
      state.tasks.forDay(uid, now),
      state.habits.active(uid),
      state.habits.logsForRange(now, now),
      state.health.waterTotal(uid, now),
      state.study.minutesForRange(now, now, userId: uid),
      state.journal.moodFor(uid, now),
      state.settings.get<String>('quran_last_surah'),
    ]);
    if (!mounted) return;
    final habits = results[1] as List<Habit>;
    final logs = results[2] as List<HabitLog>;
    setState(() {
      _tasks = results[0] as List<TaskItem>;
      _habits = habits.where((h) => state.habits.isScheduled(h, now)).toList();
      _doneHabits = logs
          .where((l) => l.state == WorshipState.completed)
          .map((l) => l.habitId)
          .toSet();
      _waterMl = results[3] as int;
      _studyMinutes = results[4] as int;
      _mood = results[5] as MoodEntry?;
      _lastSurah = results[6] as String?;
      _loading = false;
    });
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) _load();
  }

  Future<void> _toggleTask(TaskItem task) async {
    final state = AppState.of(context);
    await state.tasks.toggle(task);
    if (mounted) _load();
  }

  Future<void> _toggleHabit(Habit habit) async {
    final state = AppState.of(context);
    final done = _doneHabits.contains(habit.id);
    await state.habits.setLog(
      habitId: habit.id,
      day: DateTime.now(),
      state: done ? WorshipState.none : WorshipState.completed,
    );
    if (mounted) _load();
  }

  Future<void> _addCup() async {
    final state = AppState.of(context);
    await state.health.addWater(
      userId: state.userId,
      day: DateTime.now(),
      deltaMl: state.cupSizeMl,
    );
    if (mounted) _load();
  }

  /// هل الوقت الحالي داخل ساعات الهدوء المختارة؟
  bool _inQuietHours() {
    final r = AppState.of(context).reminders;
    if (!r.quietHoursEnabled) return false;
    final hour = DateTime.now().hour;
    if (r.quietStartHour == r.quietEndHour) return false;
    if (r.quietStartHour < r.quietEndHour) {
      return hour >= r.quietStartHour && hour < r.quietEndHour;
    }
    return hour >= r.quietStartHour || hour < r.quietEndHour;
  }

  String _moodLabel(BuildContext context, int value) {
    switch (value) {
      case 5:
        return context.tr('moodGreat');
      case 4:
        return context.tr('moodGood');
      case 3:
        return context.tr('moodOkay');
      case 2:
        return context.tr('moodLow');
      default:
        return context.tr('moodBad');
    }
  }

  String _moodEmoji(int value) {
    switch (value) {
      case 5:
        return '😄';
      case 4:
        return '🙂';
      case 3:
        return '😐';
      case 2:
        return '😔';
      default:
        return '😞';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final state = AppState.of(context);
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).languageCode;
    final tasksDone = _tasks.where((t) => t.state == TaskState.done).length;
    final habitsDone = _habits.where((h) => _doneHabits.contains(h.id)).length;
    final greeting = now.hour < 12 ? context.tr('goodMorning') : context.tr('goodEvening');
    final name = state.user?.displayName?.trim();

    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: RefreshIndicator(
              onRefresh: _load,
              color: c.primary,
              child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name == null || name.isEmpty ? greeting : '$greeting، $name',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: c.onSurface,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatFullDate(now, locale),
                          style: TextStyle(color: c.onSurfaceVariant, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _open('/settings'),
                    icon: Icon(Icons.settings_outlined, color: c.onSurfaceVariant),
                    tooltip: l10n.settings,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('homeProgressHint'),
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 12.5),
              ),
              const SizedBox(height: 16),

              // ملخص اليوم
              GlowCard(
                gradient: c.heroGradient,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.tr('todaySummary'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        _HeroStat(
                          value: '$tasksDone/${_tasks.length}',
                          label: context.tr('tasksToday'),
                          icon: Icons.task_alt,
                        ),
                        _HeroStat(
                          value: '$habitsDone/${_habits.length}',
                          label: context.tr('habitsToday'),
                          icon: Icons.emoji_objects,
                        ),
                        _HeroStat(
                          value: '$_waterMl',
                          label: context.tr('waterToday'),
                          icon: Icons.water_drop,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (state.reminders.waterEnabled &&
                  !_inQuietHours() &&
                  _waterMl < state.waterGoalMl) ...<Widget>[
                GlowCard(
                  color: c.primaryContainer,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.water_drop_outlined, color: c.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('waterReminderBanner'),
                          style: TextStyle(fontSize: 12.5, color: c.onSurface),
                        ),
                      ),
                      TextButton(
                        onPressed: _addCup,
                        child: Text(context.tr('addCup')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: <Widget>[
                  Expanded(
                    child: GlowCard(
                      onTap: () => _open('/health'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(Icons.water_drop, color: c.primary, size: 20),
                          const SizedBox(height: 8),
                          Text(
                            '$_waterMl / ${state.waterGoalMl} ${context.tr('mlShort')}',
                            style: TextStyle(fontWeight: FontWeight.w800, color: c.onSurface),
                          ),
                          const SizedBox(height: 6),
                          GlowProgress(
                            value: state.waterGoalMl == 0 ? 0.0 : _waterMl / state.waterGoalMl,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('waterOfGoal'),
                            style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlowCard(
                      onTap: () => _open('/study'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(Icons.menu_book, color: c.gold, size: 20),
                          const SizedBox(height: 8),
                          Text(
                            '$_studyMinutes ${context.tr('minutesLabel')}',
                            style: TextStyle(fontWeight: FontWeight.w800, color: c.onSurface),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('studyToday'),
                            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // المهام
              GlowSectionTitle(
                title: context.tr('tasksToday'),
                icon: Icons.task_alt,
                actionLabel: context.tr('viewAll'),
                onAction: () => _open('/tasks'),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_tasks.isEmpty)
                GlowCard(
                  child: Text(
                    context.tr('noTasksToday'),
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 13),
                  ),
                )
              else
                GlowCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: _tasks.take(4).map((task) {
                      final done = task.state == TaskState.done;
                      return CheckboxListTile(
                        value: done,
                        onChanged: (_) => _toggleTask(task),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: done ? TextDecoration.lineThrough : null,
                            color: done ? c.onSurfaceVariant : c.onSurface,
                          ),
                        ),
                        subtitle: task.dueDateTime == null
                            ? null
                            : Text(
                                formatTime(task.dueDateTime!, locale),
                                style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                              ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 14),

              // العادات
              GlowSectionTitle(
                title: context.tr('habitsToday'),
                icon: Icons.emoji_objects,
                actionLabel: context.tr('viewAll'),
                onAction: () => _open('/habits'),
              ),
              if (_habits.isEmpty)
                GlowCard(
                  child: Text(
                    context.tr('noHabitsToday'),
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 13),
                  ),
                )
              else
                GlowCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: _habits.take(4).map((habit) {
                      final done = _doneHabits.contains(habit.id);
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          done ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: done ? c.success : c.onSurfaceVariant,
                        ),
                        title: Text(habit.name),
                        onTap: () => _toggleHabit(habit),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 14),

              // المزاج
              GlowCard(
                onTap: () => _open('/journal'),
                child: Row(
                  children: <Widget>[
                    Text(
                      _mood == null ? '🌸' : _moodEmoji(_mood!.value),
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.tr('moodQuestion'),
                            style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _mood == null
                                ? context.tr('moodPromptSub')
                                : '${context.tr('moodToday')}: ${_moodLabel(context, _mood!.value)}',
                            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // إجراءات سريعة
              GlowSectionTitle(title: context.tr('quickActions'), icon: Icons.bolt),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _QuickAction(
                    icon: Icons.book,
                    label: _lastSurah == null
                        ? l10n.quran
                        : '${context.tr('quranContinue')} • $_lastSurah',
                    onTap: () => _open('/quran'),
                  ),
                  _QuickAction(
                    icon: Icons.edit_note,
                    label: context.tr('openJournal'),
                    onTap: () => _open('/journal'),
                  ),
                  _QuickAction(
                    icon: Icons.timer,
                    label: context.tr('startStudy'),
                    onTap: () => _open('/study'),
                  ),
                  _QuickAction(
                    icon: Icons.insights,
                    label: context.tr('seeProgress'),
                    onTap: () => _open('/progress'),
                  ),
                ],
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: c.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: c.onSurface, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
