/// العناية بالنفس: روتين صباحي ومسائي قابل للتعديل.
library glowara.feature.care;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';

class CareScreen extends StatefulWidget {
  const CareScreen({super.key});

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> {
  bool _didLoad = false;
  bool _loading = true;
  String _filter = 'all';
  List<SelfCareStep> _steps = <SelfCareStep>[];
  Set<String> _done = <String>{};

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
    final steps = await state.care.steps(state.userId);
    final done = await state.care.doneStepIds(DateTime.now(), userId: state.userId);
    if (!mounted) return;
    setState(() {
      _steps = steps;
      _done = done;
      _loading = false;
    });
  }

  Future<void> _openEditor({SelfCareStep? step, String period = 'morning'}) async {
    final state = AppState.of(context);
    final result = await showDialog<SelfCareStep>(
      context: context,
      builder: (_) => _CareStepDialog(
        userId: state.userId,
        step: step,
        initialPeriod: period,
      ),
    );
    if (result == null) return;
    await state.care.saveStep(result);
    if (mounted) _load();
  }

  Future<void> _delete(SelfCareStep step) async {
    final ok = await showConfirmDialog(context, title: context.l10n.confirmDelete);
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.care.deleteStep(step.id);
    if (mounted) _load();
  }

  Future<void> _toggle(SelfCareStep step) async {
    final state = AppState.of(context);
    final done = !_done.contains(step.id);
    setState(() {
      if (done) {
        _done.add(step.id);
      } else {
        _done.remove(step.id);
      }
    });
    await state.care.toggleStep(
      userId: state.userId,
      stepId: step.id,
      day: DateTime.now(),
      done: done,
    );
  }

  List<SelfCareStep> _visible(String period) {
    return _steps
        .where((s) => s.period == period && (_filter == 'all' || s.category == _filter))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final total = _steps.length;
    final done = _steps.where((s) => _done.contains(s.id)).length;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        title: Text(l10n.selfCare),
        backgroundColor: c.scaffold,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[
          IconButton(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            tooltip: context.tr('addStep'),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: <Widget>[
                  GlowCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.spa, color: c.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('careToday'),
                              style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                            ),
                            const Spacer(),
                            Text(
                              '$done/$total',
                              style: TextStyle(fontWeight: FontWeight.w700, color: c.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GlowProgress(value: total == 0 ? 0.0 : done / total),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('careSub'),
                          style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      GlowChoiceChip(
                        label: context.tr('all'),
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      GlowChoiceChip(
                        label: context.tr('skinCare'),
                        selected: _filter == 'skin',
                        onTap: () => setState(() => _filter = 'skin'),
                      ),
                      GlowChoiceChip(
                        label: context.tr('personalCare'),
                        selected: _filter == 'personal',
                        onTap: () => setState(() => _filter = 'personal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _RoutineSection(
                    title: context.tr('morningRoutine'),
                    icon: Icons.wb_sunny_outlined,
                    steps: _visible('morning'),
                    done: _done,
                    onToggle: _toggle,
                    onEdit: (step) => _openEditor(step: step),
                    onDelete: _delete,
                    onAdd: () => _openEditor(period: 'morning'),
                    addLabel: context.tr('addStep'),
                  ),
                  const SizedBox(height: 14),
                  _RoutineSection(
                    title: context.tr('eveningRoutine'),
                    icon: Icons.nightlight_outlined,
                    steps: _visible('evening'),
                    done: _done,
                    onToggle: _toggle,
                    onEdit: (step) => _openEditor(step: step),
                    onDelete: _delete,
                    onAdd: () => _openEditor(period: 'evening'),
                    addLabel: context.tr('addStep'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.notMedicalAdvice,
                    style: TextStyle(fontSize: 11, color: c.onSurfaceVariant, height: 1.5),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RoutineSection extends StatelessWidget {
  const _RoutineSection({
    required this.title,
    required this.icon,
    required this.steps,
    required this.done,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
    required this.addLabel,
  });

  final String title;
  final IconData icon;
  final List<SelfCareStep> steps;
  final Set<String> done;
  final ValueChanged<SelfCareStep> onToggle;
  final ValueChanged<SelfCareStep> onEdit;
  final ValueChanged<SelfCareStep> onDelete;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GlowSectionTitle(
          title: title,
          icon: icon,
          actionLabel: addLabel,
          onAction: onAdd,
        ),
        if (steps.isEmpty)
          GlowCard(
            child: Text(
              context.tr('noStepsSub'),
              style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant),
            ),
          )
        else
          ...steps.map((step) {
            final isDone = done.contains(step.id);
            return GlowCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: ListTile(
                dense: true,
                leading: Checkbox(
                  value: isDone,
                  onChanged: (_) => onToggle(step),
                ),
                title: Text(
                  step.title,
                  style: TextStyle(
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? c.onSurfaceVariant : c.onSurface,
                  ),
                ),
                subtitle: Text(
                  step.category == 'personal'
                      ? context.tr('personalCare')
                      : context.tr('skinCare'),
                  style: TextStyle(fontSize: 10.5, color: c.onSurfaceVariant),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit(step);
                    if (value == 'delete') onDelete(step);
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'edit', child: Text(context.l10n.edit)),
                    PopupMenuItem<String>(value: 'delete', child: Text(context.l10n.delete)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _CareStepDialog extends StatefulWidget {
  const _CareStepDialog({
    required this.userId,
    this.step,
    required this.initialPeriod,
  });

  final String userId;
  final SelfCareStep? step;
  final String initialPeriod;

  @override
  State<_CareStepDialog> createState() => _CareStepDialogState();
}

class _CareStepDialogState extends State<_CareStepDialog> {
  final _title = TextEditingController();
  late String _period;
  late String _category;

  @override
  void initState() {
    super.initState();
    final step = widget.step;
    _period = step?.period ?? widget.initialPeriod;
    _category = step?.category ?? 'skin';
    if (step != null) _title.text = step.title;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final existing = widget.step;
    Navigator.of(context).pop(
      SelfCareStep(
        id: existing?.id ?? uniqueId(),
        userId: widget.userId,
        title: title,
        period: _period,
        category: _category,
        order: existing?.order ?? 0,
        isActive: true,
        createdAt: existing?.createdAt ?? DateTime.now(),
        syncStatus: SyncStatus.local,
        lastModified: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.step == null ? context.tr('addStep') : l10n.edit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _title,
            autofocus: true,
            decoration: InputDecoration(labelText: context.tr('stepTitle')),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _period,
            decoration: InputDecoration(labelText: context.tr('morningRoutine')),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'morning', child: Text(context.tr('morningRoutine'))),
              DropdownMenuItem<String>(value: 'evening', child: Text(context.tr('eveningRoutine'))),
            ],
            onChanged: (value) => setState(() => _period = value ?? 'morning'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(labelText: context.tr('skinCare')),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'skin', child: Text(context.tr('skinCare'))),
              DropdownMenuItem<String>(value: 'personal', child: Text(context.tr('personalCare'))),
            ],
            onChanged: (value) => setState(() => _category = value ?? 'skin'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
