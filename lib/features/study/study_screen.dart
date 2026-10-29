/// قسم الدراسة: المواد، التقدم، ومواعيد الامتحانات.
library glowara.feature.study;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/repositories/study_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/study/subject_detail_screen.dart';
import 'package:go_router/go_router.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  bool _didLoad = false;
  bool _loading = true;
  List<StudySubject> _subjects = <StudySubject>[];
  Map<String, StudyProgress> _progress = <String, StudyProgress>{};

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
    final subjects = await state.study.subjects(state.userId);
    final progress = await state.study.progressForAll(state.userId);
    if (!mounted) return;
    setState(() {
      _subjects = subjects;
      _progress = progress;
      _loading = false;
    });
  }

  Future<void> _openEditor([StudySubject? subject]) async {
    final state = AppState.of(context);
    final result = await showDialog<StudySubject>(
      context: context,
      builder: (_) => _SubjectDialog(userId: state.userId, subject: subject),
    );
    if (result == null) return;
    await state.study.saveSubject(result);
    if (mounted) _load();
  }

  Future<void> _delete(StudySubject subject) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('deleteSubjectConfirm'),
      message: context.l10n.confirmDeleteSub,
    );
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.study.deleteSubject(subject.id);
    if (mounted) _load();
  }

  String _examLabel(BuildContext context, DateTime date) {
    final days = startOfDay(date).difference(startOfDay(DateTime.now())).inDays;
    if (days < 0) return context.tr('examPassed');
    if (days == 0) return context.tr('examToday');
    return '${context.tr('examInDays')} $days ${context.tr('daysShort')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final locale = Localizations.localeOf(context).languageCode;

    return GlowPage(
      title: l10n.study,
      fab: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        icon: const Icon(Icons.add),
        label: Text(context.tr('addSubject')),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? GlowEmptyState(
                  icon: Icons.menu_book,
                  title: context.tr('noSubjects'),
                  subtitle: context.tr('noSubjectsSub'),
                  actionLabel: context.tr('addSubject'),
                  onAction: () => _openEditor(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: _subjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final subject = _subjects[index];
                    final progress = _progress[subject.id] ?? const StudyProgress(done: 0, total: 0);
                    return GlowCard(
                      onTap: () async {
                        await context.push('/study/${subject.id}');
                        if (mounted) _load();
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: c.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.menu_book, color: c.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      subject.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: c.onSurface,
                                      ),
                                    ),
                                    if (subject.goal != null && subject.goal!.trim().isNotEmpty)
                                      Text(
                                        subject.goal!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant),
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _openEditor(subject);
                                  if (value == 'delete') _delete(subject);
                                },
                                itemBuilder: (context) => <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text(l10n.edit),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (subject.examDate != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Icon(Icons.event, size: 14, color: c.gold),
                                const SizedBox(width: 5),
                                Text(
                                  '${context.tr('upcomingExam')}: ${formatShortDate(subject.examDate!, locale)} — ${_examLabel(context, subject.examDate!)}',
                                  style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(child: GlowProgress(value: progress.ratio)),
                              const SizedBox(width: 8),
                              Text(
                                '${progress.done}/${progress.total}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('studyProgress'),
                            style: TextStyle(fontSize: 10.5, color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _SubjectDialog extends StatefulWidget {
  const _SubjectDialog({required this.userId, this.subject});

  final String userId;
  final StudySubject? subject;

  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  final _name = TextEditingController();
  final _goal = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _examDate;

  @override
  void initState() {
    super.initState();
    final subject = widget.subject;
    if (subject != null) {
      _name.text = subject.name;
      _goal.text = subject.goal ?? '';
      _notes.text = subject.notes ?? '';
      _examDate = subject.examDate;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now.add(const Duration(days: 14)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final existing = widget.subject;
    Navigator.of(context).pop(
      StudySubject(
        id: existing?.id ?? uniqueId(),
        userId: widget.userId,
        name: name,
        goal: _goal.text.trim().isEmpty ? null : _goal.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        examDate: _examDate,
        createdAt: existing?.createdAt ?? DateTime.now(),
        syncStatus: SyncStatus.local,
        lastModified: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    return AlertDialog(
      title: Text(widget.subject == null ? context.tr('addSubject') : context.tr('editSubject')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: widget.subject == null,
              decoration: InputDecoration(labelText: context.tr('subjectName')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _goal,
              decoration: InputDecoration(labelText: context.tr('subjectGoal')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.tr('subjectNotes')),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.tr('examDate'),
                  suffixIcon: _examDate == null
                      ? const Icon(Icons.event)
                      : IconButton(
                          onPressed: () => setState(() => _examDate = null),
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: context.tr('clearDate'),
                        ),
                ),
                child: Text(
                  _examDate == null
                      ? context.tr('noExam')
                      : formatShortDate(_examDate!, locale),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
