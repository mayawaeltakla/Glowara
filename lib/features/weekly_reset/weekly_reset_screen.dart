/// المراجعة الأسبوعية: ملخص هادئ من سجلاتها الحقيقية، وتأمّل تكتبه بنفسها.
///
/// لا درجات ولا نسب ولا مقارنة. لا تُنشأ مهام ولا إشعارات. لا مزاج ولا مذكرات
/// في الملخص. ما تكتبه محفوظ على الجهاز كبقية البيانات (ليس مقفلًا بالرمز).
library glowara.feature.weekly_reset;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/weekly_reset_models.dart';
import 'package:glowara/core/repositories/weekly_reset_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/calendar/calendar_layout.dart';

class WeeklyResetScreen extends StatefulWidget {
  /// [initialWeekStart]: أول يوم في الأسبوع المراد مراجعته؛ الافتراضي الأسبوع الحالي.
  const WeeklyResetScreen({super.key, this.initialWeekStart});

  final DateTime? initialWeekStart;

  @override
  State<WeeklyResetScreen> createState() => _WeeklyResetScreenState();
}

class _WeeklyResetScreenState extends State<WeeklyResetScreen> {
  final TextEditingController _wentWell = TextEditingController();
  final TextEditingController _needsAdjust = TextEditingController();
  final List<TextEditingController> _priorities =
      List<TextEditingController>.generate(kWeeklyMaxPriorities, (_) => TextEditingController());
  final TextEditingController _focusText = TextEditingController();
  final TextEditingController _studyPlan = TextEditingController();
  final TextEditingController _personalPlan = TextEditingController();

  bool _didLoad = false;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  int _serial = 0; // يتغيّر مع كل تحميل ليُعاد بناء القائمة المنسدلة بقيمتها الجديدة.
  Object? _error;

  late DateTime _weekStart;
  WeekSummary _summary = const WeekSummary();
  WeeklyReset? _saved;
  List<Habit> _habits = <Habit>[];
  List<WeeklyReset> _history = <WeeklyReset>[];
  WeeklyFocusType _focusType = WeeklyFocusType.none;
  String? _focusHabitId;

  List<TextEditingController> get _all => <TextEditingController>[
        _wentWell,
        _needsAdjust,
        ..._priorities,
        _focusText,
        _studyPlan,
        _personalPlan,
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    final state = AppState.of(context);
    final first = weekStartFor(state.locale);
    _weekStart = weekStartOf(widget.initialWeekStart ?? DateTime.now(), first);
    _load();
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  WeeklyResetRepository _repo(AppState state) => WeeklyResetRepository(state.db, state.progress);

  Future<void> _load() async {
    final state = AppState.of(context);
    final uid = state.userId;
    final repo = _repo(state);
    final start = _weekStart;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        repo.summary(uid, start, weekEndOf(start)),
        repo.forWeek(uid, start),
        state.habits.active(uid),
        repo.recent(uid),
      ]);
      if (!mounted || !_weekStart.isAtSameMomentAs(start)) return;
      final saved = results[1] as WeeklyReset?;
      setState(() {
        _summary = results[0] as WeekSummary;
        _saved = saved;
        _habits = results[2] as List<Habit>;
        _history = results[3] as List<WeeklyReset>;
        _fill(saved);
        _serial++;
        _dirty = false;
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

  void _fill(WeeklyReset? r) {
    _wentWell.text = r?.wentWell ?? '';
    _needsAdjust.text = r?.needsAdjustment ?? '';
    for (var i = 0; i < _priorities.length; i++) {
      _priorities[i].text = r != null && i < r.priorities.length ? r.priorities[i] : '';
    }
    _focusType = r?.focusType ?? WeeklyFocusType.none;
    _focusHabitId = r?.focusHabitId;
    if (_focusHabitId != null && !_habits.any((h) => h.id == _focusHabitId)) {
      _focusHabitId = null;
      if (_focusType == WeeklyFocusType.habit) _focusType = WeeklyFocusType.none;
    }
    _focusText.text = r?.focusText ?? '';
    _studyPlan.text = r?.studyPlan ?? '';
    _personalPlan.text = r?.personalPlan ?? '';
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        content: Text(context.tr('wkDiscard')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.tr('cancel'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(context.tr('confirm'))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _goTo(DateTime weekStart) async {
    if (!await _confirmDiscard()) return;
    if (!mounted) return;
    setState(() => _weekStart = weekStart);
    _load();
  }

  bool get _canGoNext {
    final first = weekStartFor(AppState.of(context).locale);
    return _weekStart.isBefore(weekStartOf(DateTime.now(), first));
  }

  Future<void> _save() async {
    final state = AppState.of(context);
    setState(() => _saving = true);
    try {
      await _repo(state).save(
        userId: state.userId,
        weekStart: _weekStart,
        weekEnd: weekEndOf(_weekStart),
        wentWell: _wentWell.text,
        needsAdjustment: _needsAdjust.text,
        priorities: _priorities.map((c) => c.text).toList(),
        focusType: _focusType,
        focusHabitId: _focusHabitId,
        focusText: _focusText.text,
        studyPlan: _studyPlan.text,
        personalPlan: _personalPlan.text,
      );
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('wkSaved'))));
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('somethingWentWrong'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        content: Text(context.tr('wkDeleteConfirm')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.tr('cancel'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(context.tr('delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final state = AppState.of(context);
    await _repo(state).delete(state.userId, _weekStart);
    if (mounted) _load();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String _rangeLabel(DateTime start, String locale) =>
      '${formatShortDate(start, locale)} – ${formatShortDate(weekEndOf(start), locale)}';

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final c = context.glowColors;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return GlowPage(
      title: context.tr('wkTitle'),
      child: _error != null
          ? GlowErrorView(message: context.tr('wkLoadError'), onRetry: _load)
          : ListView(
              children: <Widget>[
                GlowCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        key: const Key('wk-prev'),
                        onPressed: () => _goTo(addDays(_weekStart, -7)),
                        icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left),
                        tooltip: context.tr('wkPrevWeek'),
                      ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            _rangeLabel(_weekStart, state.locale),
                            key: const Key('wk-range'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.onSurface,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('wk-next'),
                        onPressed: _canGoNext ? () => _goTo(addDays(_weekStart, 7)) : null,
                        icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right),
                        tooltip: context.tr('wkNextWeek'),
                      ),
                    ],
                  ),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 12),
                _summaryCard(c),
                const SizedBox(height: 12),
                _reflectionCard(c),
                const SizedBox(height: 12),
                _planCard(c),
                const SizedBox(height: 12),
                Text(
                  context.tr('wkPrivacyNote'),
                  style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('wkNoAuto'),
                  style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('wk-save'),
                  onPressed: _saving || _loading ? null : _save,
                  child: Text(context.tr('wkSave')),
                ),
                if (_saved != null) ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('wk-delete'),
                    onPressed: _delete,
                    child: Text(context.tr('wkDelete')),
                  ),
                ],
                if (_history.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  GlowSectionTitle(title: context.tr('wkHistory')),
                  for (final r in _history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlowCard(
                        key: Key('wk-history-${r.weekStart}'),
                        onTap: () => _goTo(parseDateKey(r.weekStart) ?? _weekStart),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.event_note_outlined, color: c.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _rangeLabel(parseDateKey(r.weekStart) ?? _weekStart, state.locale),
                                style: TextStyle(color: c.onSurface, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _summaryCard(GlowColors c) {
    final s = _summary;
    final lines = <String>[
      if (s.tasksDone > 0) '${s.tasksDone} ${context.tr('wkTasksDone')}',
      if (s.habitDays > 0) '${s.habitDays} ${context.tr('wkHabitDays')}',
      if (s.studyMinutes > 0) '${s.studyMinutes} ${context.tr('wkStudyMinutes')}',
      if (s.waterDays > 0) '${s.waterDays} ${context.tr('wkWaterDays')}',
      if (s.careStepsDone > 0) '${s.careStepsDone} ${context.tr('wkCareSteps')}',
      if (s.lessonsCompleted > 0) '${s.lessonsCompleted} ${context.tr('wkLessons')}',
    ];
    // العبادات حضور لا أرقام.
    final worship = s.quranDays > 0 || s.adhkarCompleted > 0;
    return GlowCard(
      key: const Key('wk-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.tr('wkSummaryTitle'),
            style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
          ),
          const SizedBox(height: 8),
          if (s.isEmpty)
            Text(context.tr('wkSummaryEmpty'), style: TextStyle(color: c.onSurfaceVariant, fontSize: 13))
          else ...<Widget>[
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: TextStyle(color: c.onSurface, fontSize: 14)),
              ),
            if (worship)
              Text(
                context.tr('wkWorshipPresence'),
                style: TextStyle(color: c.onSurface, fontSize: 14),
              ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    Key key,
    TextEditingController controller,
    String label, {
    int maxLength = kWeeklyNoteMax,
    int minLines = 2,
    int maxLines = 5,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: key,
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: (_) => _markDirty(),
        textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
        decoration: InputDecoration(labelText: label, hintText: hint, counterText: ''),
      ),
    );
  }

  Widget _reflectionCard(GlowColors c) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.tr('wkReflectTitle'),
            style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
          ),
          const SizedBox(height: 12),
          _field(const Key('wk-went-well'), _wentWell, context.tr('wkWentWell')),
          _field(const Key('wk-needs-adjust'), _needsAdjust, context.tr('wkNeedsAdjust')),
        ],
      ),
    );
  }

  Widget _planCard(GlowColors c) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.tr('wkPrioritiesTitle'),
            style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _priorities.length; i++)
            _field(
              Key('wk-priority-$i'),
              _priorities[i],
              '${context.tr('wkPriority')} ${i + 1}',
              maxLength: kWeeklyPriorityMax,
              minLines: 1,
              maxLines: 1,
            ),
          const SizedBox(height: 4),
          Text(
            context.tr('wkFocusTitle'),
            style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final entry in <(WeeklyFocusType, String)>[
                (WeeklyFocusType.none, 'wkFocusNone'),
                (WeeklyFocusType.habit, 'wkFocusHabit'),
                (WeeklyFocusType.text, 'wkFocusText'),
              ])
                KeyedSubtree(
                  key: Key('wk-focus-type-${entry.$1.name}'),
                  child: GlowChoiceChip(
                    label: context.tr(entry.$2),
                    selected: _focusType == entry.$1,
                    onTap: () => setState(() {
                      _focusType = entry.$1;
                      _dirty = true;
                    }),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_focusType == WeeklyFocusType.habit)
            _habits.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      context.tr('wkNoHabits'),
                      style: TextStyle(color: c.onSurfaceVariant, fontSize: 13),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>('wk-focus-habit-pick-$_serial'),
                      initialValue: _focusHabitId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: context.tr('wkFocusHabitPick')),
                      items: <DropdownMenuItem<String>>[
                        for (final h in _habits)
                          DropdownMenuItem<String>(value: h.id, child: Text(h.name)),
                      ],
                      onChanged: (String? id) => setState(() {
                        _focusHabitId = id;
                        _dirty = true;
                      }),
                    ),
                  ),
          if (_focusType == WeeklyFocusType.text)
            _field(
              const Key('wk-focus-text'),
              _focusText,
              context.tr('wkFocusText'),
              maxLength: kWeeklyPriorityMax,
              minLines: 1,
              maxLines: 1,
              hint: context.tr('wkFocusTextHint'),
            ),
          _field(const Key('wk-study-plan'), _studyPlan, context.tr('wkStudyPlan')),
          _field(const Key('wk-personal-plan'), _personalPlan, context.tr('wkPersonalPlan')),
        ],
      ),
    );
  }
}
