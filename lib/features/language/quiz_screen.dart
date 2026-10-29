/// اختبار المفردات: اختيار من متعدد مولّد من بطاقات المستخدمة.
library glowara.feature.language.quiz;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/repositories/language_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.deckId});

  final String deckId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _didLoad = false;
  bool _loading = true;
  List<QuizItem> _items = <QuizItem>[];
  int _index = 0;
  int? _selected;
  bool _answered = false;
  bool _finished = false;
  int _correct = 0;
  final List<String> _wrongCardIds = <String>[];

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
    // عزل الحسابات: لا يُسمح باختبار مجموعة لا تخص المستخدمة الحالية.
    final decks = await state.language.decks(state.userId);
    final ownsDeck = decks.any((deck) => deck.id == widget.deckId);
    final items = ownsDeck
        ? await state.language.buildQuiz(widget.deckId)
        : <QuizItem>[];
    if (!mounted) return;
    setState(() {
      _items = items;
      _index = 0;
      _selected = null;
      _answered = false;
      _finished = false;
      _correct = 0;
      _wrongCardIds.clear();
      _loading = false;
    });
  }

  Future<void> _answer(int option) async {
    if (_answered || _finished) return;
    final state = AppState.of(context);
    final item = _items[_index];
    final isCorrect = option == item.correctIndex;
    setState(() {
      _selected = option;
      _answered = true;
      if (isCorrect) {
        _correct++;
      } else {
        _wrongCardIds.add(item.card.id);
      }
    });
    await state.language.recordAnswer(
      userId: state.userId,
      card: item.card,
      correct: isCorrect,
    );
  }

  void _next() {
    if (_index + 1 >= _items.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final l10n = context.l10n;

    return GlowPage(
      title: context.tr('quiz'),
      actions: <Widget>[
        if (!_loading && _items.isNotEmpty && !_finished)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(
              child: Text(
                '${_index + 1}/${_items.length}',
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
              ),
            ),
          ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? GlowEmptyState(
                  icon: Icons.quiz_outlined,
                  title: context.tr('quizNeedsCards'),
                  actionLabel: l10n.back,
                  onAction: () => Navigator.of(context).maybePop(),
                )
              : _finished
                  ? _buildResult(context)
                  : _buildQuestion(context),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final c = context.glowColors;
    final item = _items[_index];
    return ListView(
      children: <Widget>[
        GlowProgress(value: (_index + 1) / _items.length),
        const SizedBox(height: 18),
        Text(
          context.tr('chooseAnswer'),
          style: TextStyle(color: c.onSurfaceVariant, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        Text(
          item.card.term,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c.onSurface),
        ),
        const SizedBox(height: 18),
        ...List<Widget>.generate(item.options.length, (index) {
          final option = item.options[index];
          final isCorrect = index == item.correctIndex;
          final isSelected = index == _selected;
          Color border = c.border;
          Color background = c.surface;
          Color textColor = c.onSurface;
          if (_answered) {
            if (isCorrect) {
              border = c.success;
              background = c.success.withOpacity(0.10);
              textColor = c.success;
            } else if (isSelected) {
              border = c.danger;
              background = c.danger.withOpacity(0.10);
              textColor = c.danger;
            }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _answered ? null : () => _answer(index),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border, width: isSelected || (_answered && isCorrect) ? 1.5 : 1),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_answered && isCorrect)
                      Icon(Icons.check_circle, color: c.success, size: 20),
                    if (_answered && isSelected && !isCorrect)
                      Icon(Icons.cancel, color: c.danger, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
        if (_answered) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            _selected == item.correctIndex
                ? context.tr('correctAnswer')
                : '${context.tr('correctIs')}: ${item.options[item.correctIndex]}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _selected == item.correctIndex ? c.success : c.danger,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _next,
              child: Text(
                _index + 1 >= _items.length
                    ? context.tr('finishQuiz')
                    : context.tr('nextQuestion'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final c = context.glowColors;
    final total = _items.length;
    final ratio = total == 0 ? 0.0 : _correct / total;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${(ratio * 100).round()}%',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: c.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('quizComplete'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr('quizScore')}: $_correct / $total',
              style: TextStyle(color: c.onSurfaceVariant),
            ),
            if (_wrongCardIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '${context.tr('reviewWrong')}: ${_wrongCardIds.length}',
                style: TextStyle(color: c.warning, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.replay, size: 18),
                label: Text(context.tr('retryQuiz')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(context.l10n.back),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
