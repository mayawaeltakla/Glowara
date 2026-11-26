/// إنشاء روتين أو تعديله: الاسم والنوع والخطوات (بالترتيب) وأيام التكرار.
library glowara.feature.routine_edit;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/routine_models.dart';
import 'package:glowara/core/repositories/routine_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/calendar/calendar_layout.dart';
import 'package:glowara/features/routines/routines_screen.dart';
import 'package:intl/intl.dart' show DateFormat;

class RoutineEditScreen extends StatefulWidget {
  /// [routineId] = 'new' لروتين جديد. [templateId] لنسخ قالب اختياري.
  const RoutineEditScreen({super.key, required this.routineId, this.templateId});

  final String routineId;
  final String? templateId;

  @override
  State<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends State<RoutineEditScreen> {
  final TextEditingController _name = TextEditingController();
  final List<TextEditingController> _steps = <TextEditingController>[];
  String _kind = 'custom';
  final Set<int> _days = <int>{};
  bool _didLoad = false;
  bool _loading = true;
  bool _missing = false;
  bool get _isNew => widget.routineId == 'new';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in _steps) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    if (_isNew) {
      final t = kRoutineTemplates.where((t) => t.id == widget.templateId).firstOrNull;
      if (t != null) {
        _name.text = t.name(state.locale);
        _kind = t.kind;
        for (final s in t.steps(state.locale)) {
          _steps.add(TextEditingController(text: s));
        }
      } else {
        _steps.add(TextEditingController());
      }
    } else {
      final r = await RoutineRepository(state.db).byId(state.userId, widget.routineId);
      if (!mounted) return;
      if (r == null) {
        setState(() {
          _missing = true;
          _loading = false;
        });
        return;
      }
      _name.text = r.name;
      _kind = r.kind;
      _days.addAll(r.days);
      for (final s in r.steps) {
        _steps.add(TextEditingController(text: s.text));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _msg(String key) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  Future<void> _save() async {
    final state = AppState.of(context);
    if (_name.text.trim().isEmpty) {
      _msg('rtNameRequired');
      return;
    }
    try {
      await RoutineRepository(state.db).save(
        userId: state.userId,
        id: _isNew ? null : widget.routineId,
        name: _name.text,
        kind: _kind,
        steps: _steps.map((c) => c.text).toList(),
        days: _days.toList(),
      );
    } on StateError {
      if (mounted) _msg('rtLimit');
      return;
    }
    if (!mounted) return;
    _msg('rtSaved');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final state = AppState.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(context.tr('rtDeleteConfirm')),
        actions: <Widget>[
          TextButton(key: const Key('rt-delete-no'), onPressed: () => Navigator.of(d).pop(false), child: Text(context.tr('cancel'))),
          FilledButton(key: const Key('rt-delete-yes'), onPressed: () => Navigator.of(d).pop(true), child: Text(context.tr('rtDelete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await RoutineRepository(state.db).delete(state.userId, widget.routineId);
    if (mounted) Navigator.of(context).pop();
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _steps.length) return;
    setState(() {
      final c = _steps.removeAt(i);
      _steps.insert(j, c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppState.of(context).locale;
    final first = weekStartFor(locale);
    final order = <int>[for (var i = 0; i < 7; i++) ((first - 1 + i) % 7) + 1];
    return GlowPage(
      title: context.tr(_isNew ? 'rtNewTitle' : 'rtEdit'),
      child: _missing
          ? Center(child: Text(context.tr('rtNotFound'), key: const Key('rt-missing')))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: <Widget>[
                    TextField(
                      key: const Key('rt-name'),
                      controller: _name,
                      maxLength: kRoutineNameMax,
                      decoration: InputDecoration(labelText: context.tr('rtName'), counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    Text(context.tr('rtKind')),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        for (final k in kRoutineKinds)
                          ChoiceChip(
                            key: Key('rt-kind-$k'),
                            label: Text(context.tr(routineKindKey(k))),
                            selected: _kind == k,
                            onSelected: (_) => setState(() => _kind = k),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(context.tr('rtSteps')),
                    for (var i = 0; i < _steps.length; i++)
                      Row(
                        key: ObjectKey(_steps[i]),
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              key: Key('rt-step-field-$i'),
                              controller: _steps[i],
                              maxLength: kRoutineStepMax,
                              decoration: InputDecoration(hintText: context.tr('rtStepHint'), counterText: ''),
                            ),
                          ),
                          IconButton(
                            key: Key('rt-up-$i'),
                            tooltip: context.tr('rtMoveUp'),
                            onPressed: i == 0 ? null : () => _move(i, -1),
                            icon: const Icon(Icons.arrow_upward, size: 18),
                          ),
                          IconButton(
                            key: Key('rt-down-$i'),
                            tooltip: context.tr('rtMoveDown'),
                            onPressed: i == _steps.length - 1 ? null : () => _move(i, 1),
                            icon: const Icon(Icons.arrow_downward, size: 18),
                          ),
                          IconButton(
                            key: Key('rt-remove-$i'),
                            tooltip: context.tr('rtRemoveStep'),
                            onPressed: () => setState(() => _steps.removeAt(i).dispose()),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    if (_steps.length < kRoutineMaxSteps)
                      TextButton.icon(
                        key: const Key('rt-add-step'),
                        onPressed: () => setState(() => _steps.add(TextEditingController())),
                        icon: const Icon(Icons.add),
                        label: Text(context.tr('rtAddStep')),
                      ),
                    const SizedBox(height: 12),
                    Text(context.tr('rtDays')),
                    Wrap(
                      spacing: 6,
                      children: <Widget>[
                        for (final d in order)
                          FilterChip(
                            key: Key('rt-day-$d'),
                            label: Text(DateFormat.E(locale).format(DateTime(2024, 1, d))),
                            selected: _days.contains(d),
                            onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(key: const Key('rt-save'), onPressed: _save, child: Text(context.tr('save'))),
                    if (!_isNew)
                      TextButton(key: const Key('rt-delete'), onPressed: _delete, child: Text(context.tr('rtDelete'))),
                  ],
                ),
    );
  }
}
