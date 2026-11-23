/// روتيناتي: روتينات اليوم بخانات علامة، وقائمة كل الروتينات. بلا نسب ولا سلاسل.
library glowara.feature.routines;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/routine_models.dart';
import 'package:glowara/core/repositories/routine_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:go_router/go_router.dart';

String routineKindKey(String kind) {
  switch (kind) {
    case 'morning':
      return 'rtKindMorning';
    case 'evening':
      return 'rtKindEvening';
    default:
      return 'rtKindCustom';
  }
}

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key, this.today});

  /// لليوم المعروض؛ الافتراضي اليوم الفعلي (للاختبار).
  final DateTime? today;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  bool _didLoad = false;
  bool _loading = true;
  Object? _error;
  List<Routine> _routines = const <Routine>[];
  RoutineDay? _day;

  DateTime get _today {
    final t = widget.today ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  RoutineRepository _repo() => RoutineRepository(AppState.of(context).db);

  Future<void> _load() async {
    final state = AppState.of(context);
    try {
      final repo = _repo();
      final routines = await repo.all(state.userId);
      final day = await repo.dayFor(state.userId, _today);
      if (!mounted) return;
      setState(() {
        _routines = routines;
        _day = day;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _toggle(Routine r, RoutineStep s, bool value) async {
    final state = AppState.of(context);
    final day = await _repo().setStepDone(
      userId: state.userId,
      day: _today,
      routineId: r.id,
      stepId: s.id,
      done: value,
    );
    if (mounted) setState(() => _day = day);
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final locale = AppState.of(context).locale;
    final todays = _routines.where((r) => r.runsOn(_today) && r.steps.isNotEmpty).toList();
    return GlowPage(
      title: context.tr('rtTitle'),
      fab: FloatingActionButton.extended(
        key: const Key('rt-add'),
        onPressed: () => _open('/routines/edit/new'),
        icon: const Icon(Icons.add),
        label: Text(context.tr('rtAdd')),
      ),
      child: _error != null
          ? GlowErrorView(message: context.tr('rtLoadError'), onRetry: _load)
          : ListView(
              children: <Widget>[
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Text(
                  context.tr('rtNote'),
                  key: const Key('rt-note'),
                  style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 12),
                if (!_loading && _routines.isNotEmpty) ...<Widget>[
                  GlowSectionTitle(title: context.tr('rtTodayTitle')),
                  if (todays.isEmpty)
                    Text(context.tr('rtNoneToday'), style: TextStyle(color: c.onSurfaceVariant, fontSize: 13)),
                  for (final r in todays) _todayCard(r, c),
                  const SizedBox(height: 8),
                  GlowSectionTitle(title: context.tr('rtAllTitle')),
                  for (final r in _routines)
                    GlowCard(
                      key: Key('rt-item-${r.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _open('/routines/edit/${r.id}'),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(r.name, style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                                  Text(
                                    '${context.tr(routineKindKey(r.kind))} · ${r.steps.length}',
                                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.edit_outlined, size: 18, color: c.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                ],
                if (!_loading && _routines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(context.tr('rtEmpty'), key: const Key('rt-empty'), style: TextStyle(color: c.onSurfaceVariant)),
                  ),
                const SizedBox(height: 8),
                GlowSectionTitle(title: context.tr('rtTemplates')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final t in kRoutineTemplates)
                      ActionChip(
                        key: Key('rt-template-${t.id}'),
                        label: Text(t.name(locale)),
                        onPressed: () => _open('/routines/edit/new?template=${t.id}'),
                      ),
                  ],
                ),
                const SizedBox(height: 72),
              ],
            ),
    );
  }

  Widget _todayCard(Routine r, GlowColors c) {
    return GlowCard(
      key: Key('rt-today-${r.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(r.name, style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
          for (final s in r.steps)
            CheckboxListTile(
              key: Key('rt-step-${r.id}-${s.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _day?.isDone(r.id, s.id) ?? false,
              onChanged: (v) => _toggle(r, s, v ?? false),
              title: Text(s.text, style: const TextStyle(fontSize: 14)),
            ),
        ],
      ),
    );
  }
}
