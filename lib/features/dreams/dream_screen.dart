/// حلم: إنشاء وتعديل (العنوان والرغبة والمرحلة والموعد) وخطواته الصغيرة.
library glowara.feature.dream;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/dream_models.dart';
import 'package:glowara/core/repositories/dream_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/core/widgets/photo_slot.dart';
import 'package:glowara/features/dreams/dreams_screen.dart';

class DreamScreen extends StatefulWidget {
  /// [dreamId] = 'new' لحلم جديد.
  const DreamScreen({super.key, required this.dreamId});

  final String dreamId;

  @override
  State<DreamScreen> createState() => _DreamScreenState();
}

class _DreamScreenState extends State<DreamScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _wish = TextEditingController();
  final TextEditingController _step = TextEditingController();
  String _stage = 'dreaming';
  String? _target;
  Dream? _dream;
  bool _didLoad = false;
  bool _loading = true;
  bool _missing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _wish.dispose();
    _step.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.dreamId != 'new') {
      final state = AppState.of(context);
      final d = await DreamRepository(state.db).byId(state.userId, widget.dreamId);
      if (!mounted) return;
      if (d == null) {
        setState(() {
          _missing = true;
          _loading = false;
        });
        return;
      }
      _fill(d);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _fill(Dream d) {
    _dream = d;
    _title.text = d.title;
    _wish.text = d.wish;
    _stage = d.stage;
    _target = d.targetDate;
  }

  void _msg(String key) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _target == null ? null : DateTime.tryParse(_target!);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null && mounted) setState(() => _target = dateKey(picked));
  }

  Future<void> _save() async {
    final state = AppState.of(context);
    if (_title.text.trim().isEmpty) {
      _msg('drTitleRequired');
      return;
    }
    final wasNew = _dream == null;
    final wasAchieved = _dream?.stage == 'achieved';
    try {
      final saved = await DreamRepository(state.db).save(
        userId: state.userId,
        id: _dream?.id,
        title: _title.text,
        wish: _wish.text,
        stage: _stage,
        targetDate: _target,
      );
      if (!mounted) return;
      _msg(_stage == 'achieved' && !wasAchieved ? 'drAchievedMsg' : 'drSaved');
      if (wasNew) {
        setState(() => _fill(saved));
      } else {
        Navigator.of(context).pop();
      }
    } on StateError {
      if (mounted) _msg('drLimit');
    }
  }

  Future<void> _delete() async {
    final state = AppState.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(context.tr('drDeleteConfirm')),
        actions: <Widget>[
          TextButton(key: const Key('dr-delete-no'), onPressed: () => Navigator.of(d).pop(false), child: Text(context.tr('cancel'))),
          FilledButton(key: const Key('dr-delete-yes'), onPressed: () => Navigator.of(d).pop(true), child: Text(context.tr('drDelete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await DreamRepository(state.db).delete(state.userId, _dream!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addStep() async {
    final state = AppState.of(context);
    if (_step.text.trim().isEmpty) return;
    try {
      final d = await DreamRepository(state.db).addStep(userId: state.userId, dreamId: _dream!.id, text: _step.text);
      _step.clear();
      if (mounted) setState(() => _dream = d);
    } on StateError {
      if (mounted) _msg('drStepLimit');
    }
  }

  Future<void> _toggle(DreamStep s, bool v) async {
    final state = AppState.of(context);
    final d = await DreamRepository(state.db).setStepDone(userId: state.userId, dreamId: _dream!.id, stepId: s.id, done: v);
    if (mounted) setState(() => _dream = d);
  }

  Future<void> _removeStep(DreamStep s) async {
    final state = AppState.of(context);
    final d = await DreamRepository(state.db).deleteStep(userId: state.userId, dreamId: _dream!.id, stepId: s.id);
    if (mounted) setState(() => _dream = d);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final locale = AppState.of(context).locale;
    final targetDate = _target == null ? null : DateTime.tryParse(_target!);
    return GlowPage(
      title: context.tr(widget.dreamId == 'new' && _dream == null ? 'drNewTitle' : 'drEdit'),
      child: _missing
          ? Center(child: Text(context.tr('drNotFound'), key: const Key('dr-missing')))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: <Widget>[
                    TextField(
                      key: const Key('dr-title'),
                      controller: _title,
                      maxLength: kDreamTitleMax,
                      decoration: InputDecoration(labelText: context.tr('drDreamTitle'), counterText: ''),
                    ),
                    TextField(
                      key: const Key('dr-wish'),
                      controller: _wish,
                      maxLines: 3,
                      maxLength: kDreamWishMax,
                      decoration: InputDecoration(labelText: context.tr('drWish'), counterText: ''),
                    ),
                    if (_dream != null) ...<Widget>[
                      const SizedBox(height: 12),
                      PhotoSlot(ownerKind: 'dream', ownerId: _dream!.id),
                    ],
                    const SizedBox(height: 12),
                    Text(context.tr('drStage')),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        for (final s in kDreamStages)
                          ChoiceChip(
                            key: Key('dr-stage-$s'),
                            label: Text(context.tr(dreamStageKey(s))),
                            selected: _stage == s,
                            onSelected: (_) => setState(() => _stage = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(context.tr('drTarget')),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            targetDate == null ? context.tr('drNoDate') : formatShortDate(targetDate, locale),
                            key: const Key('dr-target'),
                          ),
                        ),
                        TextButton(key: const Key('dr-pick-date'), onPressed: _pickDate, child: Text(context.tr('drPickDate'))),
                        if (_target != null)
                          TextButton(
                            key: const Key('dr-clear-date'),
                            onPressed: () => setState(() => _target = null),
                            child: Text(context.tr('drClearDate')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(key: const Key('dr-save'), onPressed: _save, child: Text(context.tr('save'))),
                    const SizedBox(height: 20),
                    Text(context.tr('drSteps'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (_dream == null)
                      Text(context.tr('drSaveFirst'), key: const Key('dr-save-first'), style: TextStyle(color: c.onSurfaceVariant))
                    else ...<Widget>[
                      if (_dream!.steps.isEmpty)
                        Text(context.tr('drNoSteps'), style: TextStyle(color: c.onSurfaceVariant))
                      else
                        Text(dreamStepsLine(context, _dream!), key: const Key('dr-steps-count'), style: TextStyle(fontSize: 12, color: c.primary)),
                      for (final s in _dream!.steps)
                        Row(
                          key: Key('dr-step-row-${s.id}'),
                          children: <Widget>[
                            Checkbox(
                              key: Key('dr-step-${s.id}'),
                              value: s.done,
                              onChanged: (v) => _toggle(s, v ?? false),
                            ),
                            Expanded(child: Text(s.text)),
                            IconButton(
                              key: Key('dr-step-del-${s.id}'),
                              tooltip: context.tr('drRemoveStep'),
                              onPressed: () => _removeStep(s),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              key: const Key('dr-step-field'),
                              controller: _step,
                              maxLength: kDreamStepMax,
                              decoration: InputDecoration(hintText: context.tr('drStepHint'), counterText: ''),
                              onSubmitted: (_) => _addStep(),
                            ),
                          ),
                          IconButton(key: const Key('dr-add-step'), onPressed: _addStep, icon: const Icon(Icons.add)),
                        ],
                      ),
                      TextButton(key: const Key('dr-delete'), onPressed: _delete, child: Text(context.tr('drDelete'))),
                    ],
                  ],
                ),
    );
  }
}
