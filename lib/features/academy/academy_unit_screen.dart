/// صفحة وحدة: المفردات والعبارات والقاعدة، مع أزرار الدراسة والتمرين والمراجعة
/// وإضافة المفردات إلى البطاقات (بطلبها فقط).
library glowara.feature.academy.unit;

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

class AcademyUnitScreen extends StatefulWidget {
  const AcademyUnitScreen({super.key, required this.unitId});

  final String unitId;

  @override
  State<AcademyUnitScreen> createState() => _AcademyUnitScreenState();
}

class _AcademyUnitScreenState extends State<AcademyUnitScreen> {
  bool _didLoad = false;
  bool _loading = true;
  Object? _error;
  AcademyUnit? _unit;
  AcademyProgress? _progress;

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
      final progress = await AcademyRepository(state.db).forUnit(state.userId, widget.unitId);
      if (!mounted) return;
      setState(() {
        _unit = curriculum.unit(widget.unitId);
        _progress = progress;
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

  int _missedCount(AcademyUnit unit) {
    final p = _progress;
    if (p == null) return 0;
    final ids = unit.questions.map((q) => q.id).toSet();
    return p.missed.where(ids.contains).length;
  }

  Future<void> _markStudied(AcademyUnit unit) async {
    final state = AppState.of(context);
    await AcademyRepository(state.db).markStudied(state.userId, unit.id);
    if (mounted) _load();
  }

  Future<void> _practice(AcademyUnit unit, {bool review = false}) async {
    await context.push('/academy/practice/${unit.id}${review ? '?mode=review' : ''}');
    if (mounted) _load();
  }

  Future<void> _addToCards(AcademyUnit unit) async {
    final state = AppState.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        content: Text(context.tr('acAddConfirm')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.tr('cancel'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(context.tr('confirm'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final added = await AcademyRepository(state.db).addVocabularyToCards(userId: state.userId, unit: unit);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr(added > 0 ? 'acAdded' : 'acAlreadyAdded'))));
  }

  @override
  Widget build(BuildContext context) {
    final unit = _unit;
    return GlowPage(
      title: unit?.titleAr ?? context.tr('acTitle'),
      child: _error != null
          ? GlowErrorView(message: context.tr('acLoadError'), onRetry: _load)
          : _loading && unit == null
              ? const Center(child: CircularProgressIndicator())
              : unit == null
                  ? Center(child: Text(context.tr('acNotFound'), key: const Key('ac-not-found')))
                  : _content(unit),
    );
  }

  Widget _content(AcademyUnit unit) {
    final c = context.glowColors;
    final studied = _progress?.studied ?? false;
    final missed = _missedCount(unit);
    return ListView(
      children: <Widget>[
        Text(
          unit.titleEn,
          textDirection: TextDirection.ltr,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.primary),
        ),
        const SizedBox(height: 4),
        Text(unit.summaryAr, style: TextStyle(color: c.onSurfaceVariant, fontSize: 13, height: 1.5)),
        const SizedBox(height: 12),
        GlowSectionTitle(title: context.tr('acVocab')),
        for (final w in unit.vocab)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlowCard(
              key: Key('ac-word-${w.en}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          w.en,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface, fontSize: 16),
                        ),
                      ),
                      Text(w.ar, style: TextStyle(color: c.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    w.exEn,
                    textDirection: directionOf(w.exEn),
                    style: TextStyle(color: c.onSurface, fontSize: 13),
                  ),
                  Text(w.exAr, style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        GlowSectionTitle(title: context.tr('acPhrases')),
        for (final p in unit.phrases) _exampleRow(p, c),
        const SizedBox(height: 8),
        GlowSectionTitle(title: context.tr('acGrammar')),
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                unit.grammar.titleAr,
                style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                unit.grammar.bodyAr,
                style: TextStyle(color: c.onSurface, fontSize: 13, height: 1.7),
              ),
              const SizedBox(height: 8),
              for (final e in unit.grammar.examples) _exampleRow(e, c),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('ac-mark-studied'),
          onPressed: studied ? null : () => _markStudied(unit),
          child: Text(context.tr(studied ? 'acStudiedDone' : 'acMarkStudied')),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          key: const Key('ac-start-practice'),
          onPressed: () => _practice(unit),
          child: Text(context.tr('acStartPractice')),
        ),
        if (missed > 0) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('ac-review'),
            onPressed: () => _practice(unit, review: true),
            child: Text('${context.tr('acReviewMistakes')} ($missed)'),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('ac-add-cards'),
          onPressed: () => _addToCards(unit),
          child: Text(context.tr('acAddToCards')),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _exampleRow(AcademyExample e, GlowColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            e.en,
            textDirection: directionOf(e.en),
            style: TextStyle(color: c.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(e.ar, style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}
