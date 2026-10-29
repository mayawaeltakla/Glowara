/// تعلم اللغة: مجموعات كلمات، بطاقات، دروس، ومراجعة.
library glowara.feature.language;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/repositories/language_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:go_router/go_router.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool _didLoad = false;
  bool _loading = true;
  LanguageProfile? _profile;
  List<WordDeck> _decks = <WordDeck>[];
  String? _selectedDeckId;
  List<WordCard> _cards = <WordCard>[];
  List<LanguageLesson> _lessons = <LanguageLesson>[];
  List<WordCard> _wrongCards = <WordCard>[];
  VocabularyStats _vocab = const VocabularyStats(mastered: 0, total: 0);
  int _weeklyAttempts = 0;

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
    final profile = await state.language.profile(state.userId);
    final decks = await state.language.decks(state.userId);
    if (_selectedDeckId == null && decks.isNotEmpty) {
      _selectedDeckId = decks.first.id;
    }
    if (_selectedDeckId != null && !decks.any((d) => d.id == _selectedDeckId)) {
      _selectedDeckId = decks.isEmpty ? null : decks.first.id;
    }
    final cards = _selectedDeckId == null
        ? <WordCard>[]
        : await state.language.cards(_selectedDeckId!);
    final lessons = await state.language.lessons(state.userId);
    final wrong = await state.language.wrongCards(state.userId);
    final vocab = await state.language.vocabularyStats(state.userId);
    final weekly = await state.language.weeklyAttempts(state.userId);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _decks = decks;
      _cards = cards;
      _lessons = lessons;
      _wrongCards = wrong;
      _vocab = vocab;
      _weeklyAttempts = weekly;
      _loading = false;
    });
  }

  String _levelLabel(BuildContext context, String level) {
    switch (level) {
      case 'intermediate':
        return context.tr('levelIntermediate');
      case 'advanced':
        return context.tr('levelAdvanced');
      default:
        return context.tr('levelBeginner');
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final result = await showDialog<LanguageProfile>(
      context: context,
      builder: (_) => _ProfileDialog(profile: profile),
    );
    if (result == null || !mounted) return;
    final state = AppState.of(context);
    await state.language.saveProfile(result);
    if (mounted) _load();
  }

  Future<void> _addDeck() async {
    final state = AppState.of(context);
    final result = await showDialog<WordDeck>(
      context: context,
      builder: (_) => _DeckDialog(userId: state.userId),
    );
    if (result == null || !mounted) return;
    await state.language.saveDeck(result);
    _selectedDeckId = result.id;
    if (mounted) _load();
  }

  Future<void> _deleteDeck(WordDeck deck) async {
    final ok = await showConfirmDialog(context, title: context.tr('deleteDeckConfirm'));
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.language.deleteDeck(deck.id);
    _selectedDeckId = null;
    if (mounted) _load();
  }

  Future<void> _addCard() async {
    final deckId = _selectedDeckId;
    if (deckId == null) return;
    final result = await showDialog<WordCard>(
      context: context,
      builder: (_) => _CardDialog(deckId: deckId),
    );
    if (result == null || !mounted) return;
    final state = AppState.of(context);
    await state.language.saveCard(result);
    if (mounted) _load();
  }

  Future<void> _editCard(WordCard card) async {
    final result = await showDialog<WordCard>(
      context: context,
      builder: (_) => _CardDialog(deckId: card.deckId, card: card),
    );
    if (result == null || !mounted) return;
    final state = AppState.of(context);
    await state.language.saveCard(result);
    if (mounted) _load();
  }

  Future<void> _deleteCard(WordCard card) async {
    final ok = await showConfirmDialog(context, title: context.tr('deleteCardConfirm'));
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.language.deleteCard(card.id);
    if (mounted) _load();
  }

  Future<void> _addLesson() async {
    final state = AppState.of(context);
    final result = await showDialog<LanguageLesson>(
      context: context,
      builder: (_) => _LessonDialog(userId: state.userId),
    );
    if (result == null || !mounted) return;
    await state.language.saveLesson(result);
    if (mounted) _load();
  }

  Future<void> _editLesson(LanguageLesson lesson) async {
    final result = await showDialog<LanguageLesson>(
      context: context,
      builder: (_) => _LessonDialog(userId: lesson.userId, lesson: lesson),
    );
    if (result == null || !mounted) return;
    final state = AppState.of(context);
    await state.language.saveLesson(result);
    if (mounted) _load();
  }

  Future<void> _deleteLesson(LanguageLesson lesson) async {
    final ok = await showConfirmDialog(context, title: context.tr('deleteLessonConfirm'));
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.language.deleteLesson(lesson.id);
    if (mounted) _load();
  }

  Future<void> _toggleLesson(LanguageLesson lesson) async {
    final state = AppState.of(context);
    await state.language.setLessonCompleted(lesson, !lesson.isCompleted);
    if (mounted) _load();
  }

  Future<void> _openQuiz(String deckId) async {
    await context.push('/language/quiz/$deckId');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final profile = _profile;

    return DefaultTabController(
      length: 3,
      child: GlowPage(
        title: l10n.languageLearning,
        padding: EdgeInsets.zero,
        actions: <Widget>[
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: GlowCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(Icons.translate, color: c.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  profile?.targetLanguage ?? 'English',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: c.onSurface,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _editProfile,
                                child: Text(l10n.edit),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${context.tr('level')}: ${_levelLabel(context, profile?.level ?? 'beginner')} • ${context.tr('weeklyGoal')}: ${profile?.weeklyGoal ?? 20}',
                            style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          GlowLabeledProgress(
                            label: context.tr('vocabularyProgress'),
                            value: _vocab.total == 0 ? 0.0 : _vocab.mastered / _vocab.total,
                            trailing: '${_vocab.mastered}/${_vocab.total}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('languageSub'),
                            style: TextStyle(fontSize: 11, color: c.onSurfaceVariant, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TabBar(
                    labelColor: c.primary,
                    unselectedLabelColor: c.onSurfaceVariant,
                    indicatorColor: c.primary,
                    tabs: <Widget>[
                      Tab(text: context.tr('decks')),
                      Tab(text: context.tr('lessons')),
                      Tab(text: context.tr('reviewWrong')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _buildDecksTab(context),
                        _buildLessonsTab(context),
                        _buildReviewTab(context),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDecksTab(BuildContext context) {
    final c = context.glowColors;
    WordDeck? deck;
    for (final d in _decks) {
      if (d.id == _selectedDeckId) {
        deck = d;
        break;
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                context.tr('decks'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: _addDeck,
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('addDeck')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_decks.isEmpty)
          GlowEmptyState(
            icon: Icons.style_outlined,
            title: context.tr('noDecks'),
            subtitle: context.tr('noDecksSub'),
            actionLabel: context.tr('addDeck'),
            onAction: _addDeck,
          )
        else ...<Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _decks.map((d) {
              return GlowChoiceChip(
                label: d.name,
                selected: d.id == _selectedDeckId,
                onTap: () {
                  setState(() => _selectedDeckId = d.id);
                  _load();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (deck != null) ...<Widget>[
            GlowCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          deck.name,
                          style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                        ),
                        Text(
                          '${_cards.length} ${context.tr('cards')} • ${_cards.where((c) => c.isMastered).length} ${context.tr('mastered')}',
                          style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteDeck(deck!),
                    icon: Icon(Icons.delete_outline, size: 18, color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cards.length < 2 ? null : () => _openQuiz(deck!.id),
                    icon: const Icon(Icons.quiz_outlined, size: 18),
                    label: Text(context.tr('startQuiz')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addCard,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.tr('addCard')),
                  ),
                ),
              ],
            ),
            if (_cards.length < 2)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  context.tr('quizNeedsCards'),
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 10),
            if (_cards.isEmpty)
              GlowEmptyState(
                icon: Icons.style,
                title: context.tr('noCards'),
                subtitle: context.tr('noCardsSub'),
                actionLabel: context.tr('addCard'),
                onAction: _addCard,
              )
            else
              ..._cards.map((card) {
                return GlowCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              card.term,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: c.onSurface,
                              ),
                            ),
                          ),
                          if (card.isMastered)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: c.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                context.tr('mastered'),
                                style: TextStyle(fontSize: 9.5, color: c.success, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.meaning,
                        style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
                      ),
                      if (card.example.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          card.example,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: c.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          if (card.wrongCount > 0)
                            Text(
                              '${context.tr('needsReview')} (${card.wrongCount})',
                              style: TextStyle(fontSize: 10, color: c.warning),
                            ),
                          const Spacer(),
                          IconButton(
                            onPressed: () async {
                              final state = AppState.of(context);
                              await state.language.saveCard(
                                card.copyWith(isMastered: !card.isMastered),
                              );
                              if (mounted) _load();
                            },
                            icon: Icon(
                              card.isMastered ? Icons.check_circle : Icons.check_circle_outline,
                              size: 18,
                              color: card.isMastered ? c.success : c.onSurfaceVariant,
                            ),
                            tooltip: context.tr('mastered'),
                          ),
                          IconButton(
                            onPressed: () => _editCard(card),
                            icon: Icon(Icons.edit_outlined, size: 18, color: c.onSurfaceVariant),
                          ),
                          IconButton(
                            onPressed: () => _deleteCard(card),
                            icon: Icon(Icons.delete_outline, size: 18, color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ],
    );
  }

  Widget _buildLessonsTab(BuildContext context) {
    final c = context.glowColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                context.tr('lessons'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: _addLesson,
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('addLesson')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_lessons.isEmpty)
          GlowEmptyState(
            icon: Icons.menu_book,
            title: context.tr('noLessons'),
            subtitle: context.tr('noLessonsSub'),
            actionLabel: context.tr('addLesson'),
            onAction: _addLesson,
          )
        else
          ..._lessons.map((lesson) {
            return GlowCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        lesson.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                        size: 18,
                        color: lesson.isCompleted ? c.success : c.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lesson.title,
                          style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                        ),
                      ),
                      Text(
                        _levelLabel(context, lesson.level),
                        style: TextStyle(fontSize: 10, color: c.primary),
                      ),
                    ],
                  ),
                  if (lesson.content.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      lesson.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: () => _toggleLesson(lesson),
                        child: Text(
                          lesson.isCompleted
                              ? context.tr('markIncomplete')
                              : context.tr('markCompleted'),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _editLesson(lesson),
                        icon: Icon(Icons.edit_outlined, size: 18, color: c.onSurfaceVariant),
                      ),
                      IconButton(
                        onPressed: () => _deleteLesson(lesson),
                        icon: Icon(Icons.delete_outline, size: 18, color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildReviewTab(BuildContext context) {
    final c = context.glowColors;
    final goal = _profile?.weeklyGoal ?? 20;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.tr('weeklyActivity'),
                style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
              ),
              const SizedBox(height: 8),
              GlowLabeledProgress(
                label: context.tr('weeklyGoal'),
                value: goal == 0 ? 0.0 : _weeklyAttempts / goal,
                trailing: '$_weeklyAttempts/$goal',
              ),
              const SizedBox(height: 8),
              Text(
                '${context.tr('vocabularyProgress')}: ${_vocab.mastered}/${_vocab.total}',
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlowSectionTitle(title: context.tr('reviewWrong'), icon: Icons.replay),
        if (_wrongCards.isEmpty)
          GlowCard(
            child: Text(
              context.tr('noWrongCards'),
              style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
            ),
          )
        else
          ..._wrongCards.map((card) {
            WordDeck? deck;
            for (final d in _decks) {
              if (d.id == card.deckId) {
                deck = d;
                break;
              }
            }
            return GlowCard(
              margin: const EdgeInsets.only(bottom: 8),
              onTap: () => _openQuiz(card.deckId),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          card.term,
                          style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                        ),
                        Text(
                          card.meaning,
                          style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                        ),
                        if (deck != null)
                          Text(
                            deck.name,
                            style: TextStyle(fontSize: 10, color: c.primary),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${card.wrongCount}',
                    style: TextStyle(fontSize: 12, color: c.warning, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.profile});
  final LanguageProfile profile;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _language;
  late final TextEditingController _goal;
  late String _level;

  @override
  void initState() {
    super.initState();
    _language = TextEditingController(text: widget.profile.targetLanguage);
    _goal = TextEditingController(text: widget.profile.weeklyGoal.toString());
    _level = widget.profile.level;
  }

  @override
  void dispose() {
    _language.dispose();
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(context.tr('targetLanguage')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _language,
            decoration: InputDecoration(labelText: context.tr('targetLanguage')),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _level,
            decoration: InputDecoration(labelText: context.tr('level')),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'beginner', child: Text(context.tr('levelBeginner'))),
              DropdownMenuItem<String>(value: 'intermediate', child: Text(context.tr('levelIntermediate'))),
              DropdownMenuItem<String>(value: 'advanced', child: Text(context.tr('levelAdvanced'))),
            ],
            onChanged: (value) => setState(() => _level = value ?? 'beginner'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _goal,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.tr('weeklyGoal')),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final language = _language.text.trim();
            final goal = int.tryParse(_goal.text.trim()) ?? widget.profile.weeklyGoal;
            if (language.isEmpty) return;
            Navigator.of(context).pop(
              widget.profile.copyWith(
                targetLanguage: language,
                level: _level,
                weeklyGoal: goal.clamp(1, 500).toInt(),
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _DeckDialog extends StatefulWidget {
  const _DeckDialog({required this.userId});
  final String userId;

  @override
  State<_DeckDialog> createState() => _DeckDialogState();
}

class _DeckDialogState extends State<_DeckDialog> {
  final _name = TextEditingController();
  final _language = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(context.tr('addDeck')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: context.tr('deckName')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _language,
            decoration: InputDecoration(labelText: context.tr('deckLanguage')),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              WordDeck(
                id: uniqueId(),
                userId: widget.userId,
                name: name,
                language: _language.text.trim(),
                createdAt: DateTime.now(),
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _CardDialog extends StatefulWidget {
  const _CardDialog({required this.deckId, this.card});
  final String deckId;
  final WordCard? card;

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  late final TextEditingController _term;
  late final TextEditingController _meaning;
  late final TextEditingController _example;

  @override
  void initState() {
    super.initState();
    _term = TextEditingController(text: widget.card?.term ?? '');
    _meaning = TextEditingController(text: widget.card?.meaning ?? '');
    _example = TextEditingController(text: widget.card?.example ?? '');
  }

  @override
  void dispose() {
    _term.dispose();
    _meaning.dispose();
    _example.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.card == null ? context.tr('addCard') : l10n.edit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _term,
              autofocus: widget.card == null,
              decoration: InputDecoration(labelText: context.tr('term')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _meaning,
              decoration: InputDecoration(labelText: context.tr('meaning')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _example,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.tr('example')),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final term = _term.text.trim();
            final meaning = _meaning.text.trim();
            if (term.isEmpty || meaning.isEmpty) return;
            final existing = widget.card;
            Navigator.of(context).pop(
              WordCard(
                id: existing?.id ?? uniqueId(),
                deckId: widget.deckId,
                term: term,
                meaning: meaning,
                example: _example.text.trim(),
                isMastered: existing?.isMastered ?? false,
                wrongCount: existing?.wrongCount ?? 0,
                correctCount: existing?.correctCount ?? 0,
                lastReviewedAt: existing?.lastReviewedAt,
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

class _LessonDialog extends StatefulWidget {
  const _LessonDialog({required this.userId, this.lesson});
  final String userId;
  final LanguageLesson? lesson;

  @override
  State<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<_LessonDialog> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late String _level;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.lesson?.title ?? '');
    _content = TextEditingController(text: widget.lesson?.content ?? '');
    _level = widget.lesson?.level ?? 'beginner';
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.lesson == null ? context.tr('addLesson') : l10n.edit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _title,
              autofocus: widget.lesson == null,
              decoration: InputDecoration(labelText: context.tr('lessonTitle')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _level,
              decoration: InputDecoration(labelText: context.tr('level')),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'beginner', child: Text(context.tr('levelBeginner'))),
                DropdownMenuItem<String>(value: 'intermediate', child: Text(context.tr('levelIntermediate'))),
                DropdownMenuItem<String>(value: 'advanced', child: Text(context.tr('levelAdvanced'))),
              ],
              onChanged: (value) => setState(() => _level = value ?? 'beginner'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: context.tr('lessonContent'),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            final existing = widget.lesson;
            Navigator.of(context).pop(
              LanguageLesson(
                id: existing?.id ?? uniqueId(),
                userId: widget.userId,
                title: title,
                level: _level,
                content: _content.text.trim(),
                order: existing?.order ?? 0,
                completedAt: existing?.completedAt,
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
