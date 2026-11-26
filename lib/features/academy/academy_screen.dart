/// الأكاديمية: قائمة وحدات English A1 وحالة كل وحدة. بلا درجات ولا ترتيب.
library glowara.feature.academy;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/academy_models.dart';
import 'package:glowara/core/repositories/academy_repository.dart';
import 'package:glowara/core/services/academy_content.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:go_router/go_router.dart';

class AcademyScreen extends StatefulWidget {
  const AcademyScreen({super.key});

  @override
  State<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends State<AcademyScreen> {
  bool _didLoad = false;
  bool _loading = true;
  Object? _error;
  AcademyCurriculum? _curriculum;
  Map<String, AcademyProgress> _progress = <String, AcademyProgress>{};

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
      final progress = await AcademyRepository(state.db).all(state.userId);
      if (!mounted) return;
      setState(() {
        _curriculum = curriculum;
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

  Future<void> _openUnit(AcademyUnit unit) async {
    await context.push('/academy/unit/${unit.id}');
    if (mounted) _load();
  }

  int _missedCount(AcademyUnit unit) {
    final p = _progress[unit.id];
    if (p == null) return 0;
    final ids = unit.questions.map((q) => q.id).toSet();
    return p.missed.where(ids.contains).length;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final curriculum = _curriculum;
    final done = curriculum == null
        ? 0
        : curriculum.units.where((u) => _progress[u.id]?.completed ?? false).length;

    return GlowPage(
      title: context.tr('acTitle'),
      child: _error != null
          ? GlowErrorView(message: context.tr('acLoadError'), onRetry: _load)
          : ListView(
              children: <Widget>[
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.tr('acNote'),
                    key: const Key('ac-note'),
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.6),
                  ),
                ),
                if (curriculum != null) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${context.tr('acCompletedPrefix')} $done ${context.tr('of')} '
                      '${curriculum.units.length} ${context.tr('acUnitsWord')}',
                      key: const Key('ac-progress-line'),
                      style: TextStyle(color: c.onSurface, fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final unit in curriculum.units) _unitCard(unit, c),
                ],
              ],
            ),
    );
  }

  Widget _unitCard(AcademyUnit unit, GlowColors c) {
    final p = _progress[unit.id];
    final status = (p?.completed ?? false)
        ? 'acStatusDone'
        : (p?.studied ?? false)
            ? 'acStatusStudied'
            : 'acStatusNew';
    final missed = _missedCount(unit);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlowCard(
        key: Key('ac-unit-${unit.id}'),
        onTap: () => _openUnit(unit),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
              child: Text(
                '${unit.order}',
                style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    unit.titleEn,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                  ),
                  Text(unit.titleAr, style: TextStyle(color: c.onSurface, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    unit.summaryAr,
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    missed > 0
                        ? '${context.tr(status)} · $missed ${context.tr('acToReview')}'
                        : context.tr(status),
                    key: Key('ac-status-${unit.id}'),
                    style: TextStyle(color: c.onSurface, fontSize: 12),
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
