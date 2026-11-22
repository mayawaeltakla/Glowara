/// تمرين أو مراجعة وحدة. سؤال واحد في كل مرة مع شرح بعد الإجابة. بلا درجات: عند
/// الانتهاء يُحفظ فقط ما أخطأتِ فيه لتراجعيه.
library glowara.feature.academy.practice;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/academy_models.dart';
import 'package:glowara/core/repositories/academy_repository.dart';
import 'package:glowara/core/services/academy_content.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/academy/academy_text.dart';
import 'package:go_router/go_router.dart';

class AcademyPracticeScreen extends StatefulWidget {
  const AcademyPracticeScreen({super.key, required this.unitId, this.reviewOnly = false});

  final String unitId;

  /// مراجعة ما أُخطئ فيه فقط بدل كل أسئلة الوحدة.
  final bool reviewOnly;

  @override
  State<AcademyPracticeScreen> createState() => _AcademyPracticeScreenState();
}

class _AcademyPracticeScreenState extends State<AcademyPracticeScreen> {
  final Random _random = Random();

  bool _didLoad = false;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  AcademyUnit? _unit;
  List<AcademyQuestion> _questions = <AcademyQuestion>[];
  final Map<String, bool> _results = <String, bool>{};
  int _index = 0;
  List<String> _options = <String>[];
  String? _selected;
  bool _finished = false;
  int _toReview = 0;

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
      final curriculum = await AcademyContent.loadA1();
      final unit = curriculum.unit(widget.unitId);
      var questions = unit?.questions ?? <AcademyQuestion>[];
      if (unit != null && widget.reviewOnly) {
        final progress = await AcademyRepository(state.db).forUnit(state.userId, unit.id);
        final missed = progress?.missed.toSet() ?? <String>{};
        questions = questions.where((q) => missed.contains(q.id)).toList();
      }
      if (!mounted) return;
      setState(() {
        _unit = unit;
        _questions = questions;
        _index = 0;
        _selected = null;
        _finished = false;
        _results.clear();
        _options = questions.isEmpty ? <String>[] : _shuffled(questions.first);
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

  List<String> _shuffled(AcademyQuestion q) => List<String>.of(q.options)..shuffle(_random);

  void _choose(String option) {
    if (_selected != null) return;
    final q = _questions[_index];
    setState(() {
      _selected = option;
      _results[q.id] = option == q.correctOption;
    });
  }

  Future<void> _next() async {
    if (_index + 1 < _questions.length) {
      setState(() {
        _index++;
        _selected = null;
        _options = _shuffled(_questions[_index]);
      });
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    final state = AppState.of(context);
    final unit = _unit;
    if (unit == null || _saving) return;
    setState(() => _saving = true);
    try {
      final progress = await AcademyRepository(state.db).recordPractice(
        userId: state.userId,
        unitId: unit.id,
        results: Map<String, bool>.of(_results),
      );
      if (!mounted) return;
      final ids = unit.questions.map((q) => q.id).toSet();
      setState(() {
        _toReview = progress.missed.where(ids.contains).length;
        _finished = true;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('somethingWentWrong'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.reviewOnly ? context.tr('acReviewTitle') : context.tr('acPracticeTitle');
    return GlowPage(
      title: title,
      child: _error != null
          ? GlowErrorView(message: context.tr('acLoadError'), onRetry: _load)
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _unit == null
                  ? Center(child: Text(context.tr('acNotFound'), key: const Key('ac-not-found')))
                  : _questions.isEmpty
                      ? _message(context.tr('acNothingToReview'), const Key('ac-nothing'))
                      : _finished
                          ? _doneView()
                          : _questionView(),
    );
  }

  Widget _message(String text, Key key) {
    final c = context.glowColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(text, key: key, style: TextStyle(color: c.onSurface, fontSize: 15)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('ac-back'),
            onPressed: () => context.pop(),
            child: Text(context.tr('acBack')),
          ),
        ],
      ),
    );
  }

  Widget _doneView() {
    final c = context.glowColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_outline, color: c.primary, size: 48),
          const SizedBox(height: 12),
          Text(
            context.tr('acDoneTitle'),
            key: const Key('ac-done-title'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('acDoneBody'),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 13, height: 1.6),
          ),
          if (_toReview > 0) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '$_toReview ${context.tr('acToReview')}',
              key: const Key('ac-to-review'),
              style: TextStyle(color: c.onSurface, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('ac-back'),
            onPressed: () => context.pop(),
            child: Text(context.tr('acBack')),
          ),
        ],
      ),
    );
  }

  Widget _questionView() {
    final c = context.glowColors;
    final q = _questions[_index];
    final answered = _selected != null;
    final correct = answered && _selected == q.correctOption;
    final isLast = _index + 1 == _questions.length;
    return ListView(
      children: <Widget>[
        Text(
          '${_index + 1} ${context.tr('of')} ${_questions.length}',
          key: const Key('ac-position'),
          style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          q.prompt,
          key: const Key('ac-prompt'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.onSurface, height: 1.5),
        ),
        const SizedBox(height: 12),
        for (final option in _options) _optionButton(q, option, c),
        if (answered) ...<Widget>[
          const SizedBox(height: 8),
          GlowCard(
            key: const Key('ac-feedback'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      correct ? Icons.check_circle_outline : Icons.info_outline,
                      color: c.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr(correct ? 'acCorrect' : 'acIncorrect'),
                      style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                    ),
                  ],
                ),
                if (!correct) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    '${context.tr('acCorrectAnswer')}: ${q.correctOption}',
                    textDirection: directionOf(q.correctOption),
                    style: TextStyle(color: c.onSurface, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 6),
                Text(q.why, style: TextStyle(color: c.onSurfaceVariant, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('ac-next'),
            onPressed: _saving ? null : _next,
            child: Text(context.tr(isLast ? 'acFinish' : 'acNext')),
          ),
        ],
      ],
    );
  }

  Widget _optionButton(AcademyQuestion q, String option, GlowColors c) {
    final answered = _selected != null;
    final isCorrect = option == q.correctOption;
    final isChosen = option == _selected;
    IconData? icon;
    if (answered && isCorrect) {
      icon = Icons.check_circle_outline;
    } else if (answered && isChosen) {
      icon = Icons.cancel_outlined;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        key: Key('ac-option-$option'),
        onPressed: answered ? null : () => _choose(option),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(
            color: answered && (isCorrect || isChosen) ? c.primary : c.border,
            width: answered && (isCorrect || isChosen) ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[Icon(icon, size: 18), const SizedBox(width: 8)],
            Flexible(
              child: Text(
                option,
                textDirection: directionOf(option),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
