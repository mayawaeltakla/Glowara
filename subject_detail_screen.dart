/// تفاصيل مادة: المحاضرات، جلسات الدراسة، والمؤقت.
library glowara.feature.study.detail;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/repositories/study_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';

class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  bool _didLoad = false;
  bool _loading = true;
  int _tab = 0;
  StudySubject? _subject;
  List<StudyUnit> _units = <StudyUnit>[];
  List<StudySession> _sessions = <StudySession>[];
  StudyProgress _progress = const StudyProgress(done: 0, total: 0);

  DateTime? _timerStart;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    final subject = await state.study.subject(widget.subjectId);
    // عزل الحسابات: لا نعرض مادة لا تخص المستخدمة الحالية.
    if (subject == null || subject.userId != state.userId) {
      if (!mounted) return;
      setState(() {
        _subject = null;
        _units = <StudyUnit>[];
        _sessions = <StudySession>[];
        _progress = const StudyProgress(done: 0, total: 0);
        _loading = false;
      });
      return;
    }
    final units = await state.study.units(widget.subjectId);
    final sessions = await state.study.sessions(
      subjectId: widget.subjectId,
      userId: state.userId,
    );
    final progress = await state.study.progress(widget.subjectId);
    if (!mounted) return;
    setState(() {
      _subject = subject;
      _units = units;
      _sessions = sessions;
      _progress = progress;
      _loading = false;
    });
  }

  Future<void> _addUnit() async {
    final title = await showTextInputDialog(
      context,
      title: context.tr('addUnit'),
      hint: context.tr('unitTitle'),
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    final state = AppState.of(context);
    await state.study.saveUnit(
      StudyUnit(
        id: uniqueId(),
        subjectId: widget.subjectId,
        title: title.trim(),
        createdAt: DateTime.now(),
        syncStatus: SyncStatus.local,
        lastModified: DateTime.now(),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _editUnit(StudyUnit unit) async {
    final title = await showTextInputDialog(
      context,
      title: context.l10n.edit,
      initialValue: unit.title,
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    final state = AppState.of(context);
    await state.study.saveUnit(unit.copyWith(title: title.trim()));
    if (mounted) _load();
  }

  Future<void> _deleteUnit(StudyUnit unit) async {
    final ok = await showConfirmDialog(context, title: context.tr('deleteUnitConfirm'));
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.study.deleteUnit(unit.id);
    if (mounted) _load();
  }

  void _startTimer() {
    setState(() {
      _timerStart = DateTime.now();
      _elapsed = Duration.zero;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _timerStart == null) return;
      setState(() => _elapsed = DateTime.now().difference(_timerStart!));
    });
  }

  Future<void> _finishTimer({required bool save}) async {
    final start = _timerStart;
    final elapsed = _elapsed;
    _ticker?.cancel();
    setState(() {
      _timerStart = null;
      _elapsed = Duration.zero;
    });
    if (!save || start == null || !mounted) return;
    final minutes = elapsed.inMinutes < 1 ? 1 : elapsed.inMinutes;
    final state = AppState.of(context);
    await state.study.saveSession(
      StudySession(
        id: uniqueId(),
        userId: state.userId,
        subjectId: widget.subjectId,
        startedAt: start,
        endedAt: DateTime.now(),
        durationMinutes: minutes,
        createdAt: DateTime.now(),
        syncStatus: SyncStatus.local,
        lastModified: DateTime.now(),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('sessionSaved'))),
      );
      _load();
    }
  }

  Future<void> _manualSession() async {
    final minutes = TextEditingController(text: '30');
    final notes = TextEditingController();
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('addSession')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: minutes,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('sessionMinutes')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.tr('sessionNotes')),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (result != true || !mounted) {
      minutes.dispose();
      notes.dispose();
      return;
    }
    final value = int.tryParse(minutes.text.trim()) ?? 0;
    final noteText = notes.text.trim();
    minutes.dispose();
    notes.dispose();
    if (value <= 0) return;
    final state = AppState.of(context);
    final now = DateTime.now();
    await state.study.saveSession(
      StudySession(
        id: uniqueId(),
        userId: state.userId,
        subjectId: widget.subjectId,
        startedAt: now.subtract(Duration(minutes: value)),
        endedAt: now,
        durationMinutes: value,
        notes: noteText.isEmpty ? null : noteText,
        createdAt: now,
        syncStatus: SyncStatus.local,
        lastModified: now,
      ),
    );
    if (mounted) _load();
  }

  Future<void> _deleteSession(StudySession session) async {
    final state = AppState.of(context);
    await state.study.deleteSession(session.id);
    if (mounted) _load();
  }

  String _duration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final locale = Localizations.localeOf(context).languageCode;
    final subject = _subject;

    return GlowPage(
      title: subject?.name ?? l10n.study,
      actions: <Widget>[
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: l10n.loading,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : subject == null
              ? GlowEmptyState(
                  icon: Icons.error_outline,
                  title: context.tr('somethingWentWrong'),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: <Widget>[
                    GlowCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (subject.goal != null && subject.goal!.isNotEmpty) ...<Widget>[
                            Text(
                              subject.goal!,
                              style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (subject.examDate != null) ...<Widget>[
                            Row(
                              children: <Widget>[
                                Icon(Icons.event, size: 15, color: c.gold),
                                const SizedBox(width: 6),
                                Text(
                                  '${context.tr('examDate')}: ${formatShortDate(subject.examDate!, locale)}',
                                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (subject.notes != null && subject.notes!.isNotEmpty) ...<Widget>[
                            Text(
                              subject.notes!,
                              style: TextStyle(fontSize: 12, color: c.onSurfaceVariant, height: 1.5),
                            ),
                            const SizedBox(height: 6),
                          ],
                          const SizedBox(height: 4),
                          GlowLabeledProgress(
                            label: context.tr('studyProgress'),
                            value: _progress.ratio,
                            trailing: '${_progress.done}/${_progress.total}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: <ButtonSegment<int>>[
                        ButtonSegment<int>(
                          value: 0,
                          icon: const Icon(Icons.list_alt, size: 16),
                          label: Text(context.tr('units')),
                        ),
                        ButtonSegment<int>(
                          value: 1,
                          icon: const Icon(Icons.timer_outlined, size: 16),
                          label: Text(context.tr('studySessions')),
                        ),
                      ],
                      selected: <int>{_tab},
                      onSelectionChanged: (value) => setState(() => _tab = value.first),
                    ),
                    const SizedBox(height: 12),
                    if (_tab == 0) ..._buildUnits(context) else ..._buildSessions(context),
                  ],
                ),
    );
  }

  List<Widget> _buildUnits(BuildContext context) {
    final c = context.glowColors;
    return <Widget>[
      GlowSectionTitle(
        title: context.tr('units'),
        actionLabel: context.tr('addUnit'),
        onAction: _addUnit,
        icon: Icons.list_alt,
      ),
      if (_units.isEmpty)
        GlowCard(
          child: Text(
            context.tr('noUnitsSub'),
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 13),
          ),
        )
      else
        ..._units.map((unit) {
          final done = unit.state == TaskState.done;
          return GlowCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              dense: true,
              leading: Checkbox(
                value: done,
                onChanged: (_) async {
                  final state = AppState.of(context);
                  await state.study.setUnitState(
                    unit,
                    done ? TaskState.open : TaskState.done,
                  );
                  if (mounted) _load();
                },
              ),
              title: Text(
                unit.title,
                style: TextStyle(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? c.onSurfaceVariant : c.onSurface,
                ),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _editUnit(unit);
                  if (value == 'delete') _deleteUnit(unit);
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'edit', child: Text(context.l10n.edit)),
                  PopupMenuItem<String>(value: 'delete', child: Text(context.l10n.delete)),
                ],
              ),
            ),
          );
        }),
    ];
  }

  List<Widget> _buildSessions(BuildContext context) {
    final c = context.glowColors;
    final locale = Localizations.localeOf(context).languageCode;
    final totalMinutes = _sessions.fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));
    return <Widget>[
      GlowCard(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.timer, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _timerStart == null
                        ? context.tr('startTimer')
                        : _duration(_elapsed),
                    style: TextStyle(
                      fontSize: _timerStart == null ? 14 : 28,
                      fontWeight: FontWeight.w800,
                      color: c.onSurface,
                    ),
                  ),
                ),
                if (_timerStart == null)
                  FilledButton.icon(
                    onPressed: _startTimer,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(context.tr('startTimer')),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _finishTimer(save: true),
                    icon: const Icon(Icons.stop, size: 18),
                    label: Text(context.tr('finishSession')),
                  ),
              ],
            ),
            if (_timerStart != null) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => _finishTimer(save: false),
                  child: Text(context.l10n.cancel),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _manualSession,
        icon: const Icon(Icons.add, size: 18),
        label: Text(context.tr('addSession')),
      ),
      const SizedBox(height: 12),
      Row(
        children: <Widget>[
          Text(
            context.tr('totalStudyMinutes'),
            style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            '$totalMinutes ${context.tr('minutesLabel')}',
            style: TextStyle(fontWeight: FontWeight.w700, color: c.primary),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_sessions.isEmpty)
        GlowCard(
          child: Text(
            context.tr('noSessions'),
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 13),
          ),
        )
      else
        ..._sessions.map((session) {
          return GlowCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${session.durationMinutes ?? 0}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.primary, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${session.durationMinutes ?? 0} ${context.tr('minutesLabel')}',
                        style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                      ),
                      Text(
                        '${formatShortDate(session.startedAt, locale)} • ${formatTime(session.startedAt, locale)}',
                        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                      ),
                      if (session.notes != null && session.notes!.isNotEmpty)
                        Text(
                          session.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteSession(session),
                  icon: Icon(Icons.delete_outline, color: c.onSurfaceVariant, size: 18),
                ),
              ],
            ),
          );
        }),
    ];
  }
}
