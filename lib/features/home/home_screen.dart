/// شاشة "اليوم": ملخص حقيقي للمهام والعادات والماء والدراسة والمزاج.
library glowara.feature.home;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/worship/adhkar_screen.dart' show doneFlagKey;
import 'package:glowara/features/worship/dua_screen.dart' show kDuas;
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
  bool _morningDone = false;
  bool _eveningDone = false;
  int _duaDone = 0;
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
      state.settings.get<String>(doneFlagKey(true, now)),
      state.settings.get<String>(doneFlagKey(false, now)),
      state.settings.get<String>('dua_done_${dateKey(now)}'),
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
      _morningDone = results[7] == '1';
      _eveningDone = results[8] == '1';
      final duaRaw = results[9] as String?;
      _duaDone = (duaRaw == null || duaRaw.isEmpty)
          ? 0
          : duaRaw.split(',').map(int.tryParse).whereType<int>().where((i) => i < kDuas.length).length;
      _loading = false;
    });
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) _load();
  }

  Future<void> _toggleTask(TaskItem task) async {
    final state = AppState.of(context);
    await state.tasks.toggle(task, day: DateTime.now());
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

  /// متوسط إنجاز ما له هدف اليوم (المهام والعادات والماء).
  double _balance(int tasksDone, int habitsDone, int waterGoal) {
    final parts = <double>[
      if (_tasks.isNotEmpty) tasksDone / _tasks.length,
      if (_habits.isNotEmpty) habitsDone / _habits.length,
      if (waterGoal > 0) (_waterMl / waterGoal).clamp(0.0, 1.0).toDouble(),
      ((_morningDone ? 1 : 0) + (_eveningDone ? 1 : 0)) / 2,
      if (kDuas.isNotEmpty) _duaDone / kDuas.length,
    ];
    if (parts.isEmpty) return 0;
    return parts.reduce((a, b) => a + b) / parts.length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final state = AppState.of(context);
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).languageCode;
    final tasksDone = _tasks.where((t) => t.isDoneOn(now)).length;
    final habitsDone = _habits.where((h) => _doneHabits.contains(h.id)).length;
    final greeting = now.hour < 12 ? context.tr('goodMorning') : context.tr('goodEvening');
    final name = state.user?.displayName?.trim();
    final waterGoal = state.waterGoalMl;
    final balance = _balance(tasksDone, habitsDone, waterGoal);

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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: <Widget>[
                  // الترحيب والتاريخ
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: c.surfaceAlt,
                                borderRadius: BorderRadius.circular(GlowRadius.pill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.calendar_today_outlined, size: 13, color: c.primary),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      formatFullDate(now, locale),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: c.onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name == null || name.isEmpty ? greeting : '$greeting، $name',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: c.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RoundIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: l10n.settings,
                        onTap: () => _open('/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('homeProgressHint'),
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 18),

                  // إشراقة يومك
                  _DayGlowCard(
                    title: context.tr('dayGlow'),
                    balanceLabel: context.tr('dayBalance'),
                    balance: balance,
                    rows: <_GlowRow>[
                      _GlowRow(
                        label: context.tr('tasksToday'),
                        trailing: '$tasksDone/${_tasks.length}',
                        fraction: _tasks.isEmpty ? 0 : tasksDone / _tasks.length,
                      ),
                      _GlowRow(
                        label: context.tr('habitsToday'),
                        trailing: '$habitsDone/${_habits.length}',
                        fraction: _habits.isEmpty ? 0 : habitsDone / _habits.length,
                      ),
                      _GlowRow(
                        label: context.tr('waterToday'),
                        trailing: '$_waterMl ${context.tr('mlShort')}',
                        fraction: waterGoal == 0 ? 0 : (_waterMl / waterGoal).clamp(0.0, 1.0).toDouble(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (state.reminders.waterEnabled &&
                      !_inQuietHours() &&
                      _waterMl < waterGoal) ...<Widget>[
                    GlowCard(
                      color: c.primaryContainer,
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.water_drop_outlined, color: c.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('waterReminderBanner'),
                              style: TextStyle(fontSize: 13, color: c.onSurface),
                            ),
                          ),
                          TextButton(
                            onPressed: _addCup,
                            child: Text(context.tr('addCup')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // الماء بالقطرات
                  _WaterCard(
                    title: context.tr('waterToday'),
                    amountLabel: '$_waterMl / $waterGoal ${context.tr('mlShort')}',
                    cups: waterGoal <= 0 ? 0 : (waterGoal / state.cupSizeMl).ceil().clamp(1, 16).toInt(),
                    filled: (_waterMl / state.cupSizeMl).floor().clamp(0, 16).toInt(),
                    addTooltip: context.tr('addCup'),
                    onAdd: _addCup,
                    onOpen: () => _open('/health'),
                  ),
                  const SizedBox(height: 18),

                  // أركان يومك
                  GlowSectionTitle(
                    title: context.tr('homeCorners'),
                    icon: Icons.spa_outlined,
                    actionLabel: context.tr('seeProgress'),
                    onAction: () => _open('/progress'),
                  ),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _CornerTile(
                            icon: Icons.menu_book_outlined,
                            tint: c.gold,
                            title: l10n.quran,
                            subtitle: _lastSurah == null
                                ? null
                                : '${context.tr('quranContinue')} • $_lastSurah',
                            onTap: () => _open('/quran'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CornerTile(
                            icon: Icons.timer_outlined,
                            tint: c.primary,
                            title: context.tr('startStudy'),
                            subtitle: '$_studyMinutes ${context.tr('minutesLabel')}',
                            onTap: () => _open('/study'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _CornerTile(
                            icon: Icons.edit_note,
                            tint: c.blush,
                            title: context.tr('openJournal'),
                            subtitle: _mood == null
                                ? null
                                : '${_moodEmoji(_mood!.value)} ${_moodLabel(context, _mood!.value)}',
                            onTap: () => _open('/journal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CornerTile(
                            icon: Icons.favorite_border,
                            tint: c.lilac,
                            title: l10n.selfCare,
                            onTap: () => _open('/care'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // المزاج
                  GlowCard(
                    onTap: () => _open('/journal'),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.blush.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _mood == null ? '🌸' : _moodEmoji(_mood!.value),
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

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
                    ..._tasks.take(4).map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CheckRow(
                              title: task.title,
                              subtitle: task.dueDateTime == null
                                  ? null
                                  : formatTime(task.dueDateTime!, locale),
                              done: task.isDoneOn(now),
                              onTap: () => _toggleTask(task),
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),

                  // العادات
                  GlowSectionTitle(
                    title: context.tr('habitsToday'),
                    icon: Icons.emoji_objects_outlined,
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
                    ..._habits.take(4).map(
                          (habit) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CheckRow(
                              title: habit.name,
                              done: _doneHabits.contains(habit.id),
                              onTap: () => _toggleHabit(habit),
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),

                  // عبادة اليوم
                  GlowSectionTitle(
                    title: context.tr('worshipToday'),
                    icon: Icons.mosque,
                    actionLabel: context.tr('viewAll'),
                    onAction: () => _open('/worship'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CheckRow(
                      title: context.tr('morningAdhkar'),
                      done: _morningDone,
                      onTap: () => _open('/worship'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CheckRow(
                      title: context.tr('eveningAdhkar'),
                      done: _eveningDone,
                      onTap: () => _open('/worship'),
                    ),
                  ),
                  _CheckRow(
                    title: context.tr('duaToday'),
                    subtitle: '$_duaDone/${kDuas.length}',
                    done: _duaDone >= kDuas.length,
                    onTap: () => _open('/worship'),
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

/// زر أيقونة دائري بخلفية ناعمة.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.surface,
        shape: CircleBorder(side: BorderSide(color: c.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: c.primary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// صف في بطاقة «إشراقة يومك»: اسم + قيمة + شريط تقدم.
class _GlowRow {
  const _GlowRow({required this.label, required this.trailing, required this.fraction});

  final String label;
  final String trailing;
  final double fraction;
}

/// بطاقة «إشراقة يومك»: حلقة التوازن وأشرطة المهام والعادات والماء.
class _DayGlowCard extends StatelessWidget {
  const _DayGlowCard({
    required this.title,
    required this.balanceLabel,
    required this.balance,
    required this.rows,
  });

  final String title;
  final String balanceLabel;
  final double balance;
  final List<_GlowRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final percent = (balance * 100).round();
    final soft = Colors.white.withValues(alpha: 0.85);
    return Container(
      decoration: BoxDecoration(
        gradient: c.heroGradient,
        borderRadius: BorderRadius.circular(GlowRadius.sheet),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlowRadius.sheet),
        child: Stack(
          children: <Widget>[
            // دوائر زخرفية ناعمة
            Positioned(
              top: -46,
              left: -30,
              child: _GlowDot(size: 150, color: Colors.white.withValues(alpha: 0.07)),
            ),
            Positioned(
              bottom: -50,
              right: -20,
              child: _GlowDot(size: 130, color: c.gold.withValues(alpha: 0.16)),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          children: rows
                              .map(
                                (row) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              row.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(color: soft, fontSize: 12.5),
                                            ),
                                          ),
                                          Text(
                                            row.trailing,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: row.fraction.clamp(0.0, 1.0).toDouble(),
                                          minHeight: 6,
                                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                                          valueColor: const AlwaysStoppedAnimation<Color>(
                                            Color(0xFFF3D9A6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Semantics(
                        label: '$balanceLabel $percent%',
                        excludeSemantics: true,
                        child: SizedBox(
                          width: 104,
                          height: 104,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: balance),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => CustomPaint(
                              painter: _RingPainter(
                                fraction: value,
                                track: Colors.white.withValues(alpha: 0.22),
                                fill: const Color(0xFFF3D9A6),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      '$percent%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      balanceLabel,
                                      style: TextStyle(color: soft, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowDot extends StatelessWidget {
  const _GlowDot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// حلقة تقدم دائرية بأطراف مستديرة.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.track, required this.fill});

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);
    if (fraction <= 0) return;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.fill != fill;
}

/// بطاقة الماء بقطرات تمثل الأكواب.
class _WaterCard extends StatelessWidget {
  const _WaterCard({
    required this.title,
    required this.amountLabel,
    required this.cups,
    required this.filled,
    required this.addTooltip,
    required this.onAdd,
    required this.onOpen,
  });

  final String title;
  final String amountLabel;
  final int cups;
  final int filled;
  final String addTooltip;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return GlowCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.lilac.withValues(alpha: 0.30),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.water_drop, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                    ),
                    Text(
                      amountLabel,
                      style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: onAdd,
                tooltip: addTooltip,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (cups > 0) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List<Widget>.generate(
                cups,
                (i) => Icon(
                  i < filled ? Icons.water_drop : Icons.water_drop_outlined,
                  size: 22,
                  color: i < filled ? c.primary : c.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ركن من أركان اليوم: أيقونة في دائرة ملوّنة + عنوان + سطر اختياري.
class _CornerTile extends StatelessWidget {
  const _CornerTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final sub = subtitle;
    return GlowCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: c.primary, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: c.onSurface),
          ),
          if (sub != null && sub.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// صف مهمة/عادة بدائرة إنجاز، يلمسه المستخدم لتبديل الحالة.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.title,
    required this.done,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final sub = subtitle;
    return Semantics(
      button: true,
      checked: done,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(GlowRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(GlowRadius.card),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GlowRadius.card),
              border: Border.all(color: c.border.withValues(alpha: 0.8)),
            ),
            child: Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: done ? c.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done ? c.primary : c.onSurfaceVariant.withValues(alpha: 0.6),
                      width: 1.6,
                    ),
                  ),
                  child: done ? Icon(Icons.check, size: 16, color: c.onPrimary) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: done ? c.onSurfaceVariant : c.onSurface,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (sub != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
