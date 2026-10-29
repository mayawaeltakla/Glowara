/// العادات: متابعة لطيفة دون سلاسل عقابية.
library glowara.feature.habits;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:intl/intl.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  bool _didLoad = false;
  bool _loading = true;
  List<Habit> _habits = <Habit>[];
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
    final now = DateTime.now();
    final habits = await state.habits.all(state.userId);
    final logs = await state.habits.logsForRange(now, now);
    if (!mounted) return;
    setState(() {
      _habits = habits;
      _done = logs
          .where((l) => l.state == WorshipState.completed)
          .map((l) => l.habitId)
          .toSet();
      _loading = false;
    });
  }

  Future<void> _openEditor([Habit? habit]) async {
    final state = AppState.of(context);
    final result = await showDialog<Habit>(
      context: context,
      builder: (_) => _HabitDialog(userId: state.userId, habit: habit),
    );
    if (result == null || !mounted) return;
    await state.habits.save(result);
    if (mounted) _load();
  }

  Future<void> _delete(Habit habit) async {
    final ok = await showConfirmDialog(context, title: context.tr('deleteHabitConfirm'));
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.habits.delete(habit.id);
    if (mounted) _load();
  }

  Future<void> _toggle(Habit habit) async {
    final state = AppState.of(context);
    final done = !_done.contains(habit.id);
    setState(() {
      if (done) {
        _done.add(habit.id);
      } else {
        _done.remove(habit.id);
      }
    });
    await state.habits.setLog(
      habitId: habit.id,
      day: DateTime.now(),
      state: done ? WorshipState.completed : WorshipState.none,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(done ? 'habitCompleted' : 'habitUnmarked')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final state = AppState.of(context);
    final now = DateTime.now();
    final scheduled = _habits.where((h) => state.habits.isScheduled(h, now)).toList();
    final done = scheduled.where((h) => _done.contains(h.id)).length;

    return GlowPage(
      title: context.tr('sectionHabits'),
      fab: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        icon: const Icon(Icons.add),
        label: Text(context.tr('addHabit')),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: <Widget>[
                GlowCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.emoji_objects, color: c.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('todayHabits'),
                            style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                          ),
                          const Spacer(),
                          Text(
                            '$done/${scheduled.length}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: c.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GlowProgress(
                        value: scheduled.isEmpty ? 0.0 : done / scheduled.length,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('habitsSub'),
                        style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_habits.isEmpty)
                  GlowEmptyState(
                    icon: Icons.emoji_objects,
                    title: context.tr('noHabits'),
                    subtitle: context.tr('noHabitsSub'),
                    actionLabel: context.tr('addHabit'),
                    onAction: () => _openEditor(),
                  )
                else
                  ..._habits.map((habit) {
                    final isScheduled = state.habits.isScheduled(habit, now);
                    final isDone = _done.contains(habit.id);
                    return GlowCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: ListTile(
                        leading: Checkbox(
                          value: isDone,
                          onChanged: isScheduled ? (_) => _toggle(habit) : null,
                        ),
                        title: Text(
                          habit.name,
                          style: TextStyle(
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isScheduled ? c.onSurface : c.onSurfaceVariant,
                          ),
                        ),
                        subtitle: Text(
                          !habit.isActive
                              ? context.tr('inactiveHabit')
                              : isScheduled
                                  ? (habit.description?.isNotEmpty ?? false
                                      ? habit.description!
                                      : _scheduleLabel(context, habit))
                                  : context.tr('notScheduledToday'),
                          style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _openEditor(habit);
                            if (value == 'delete') _delete(habit);
                          },
                          itemBuilder: (context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(value: 'edit', child: Text(l10n.edit)),
                            PopupMenuItem<String>(value: 'delete', child: Text(l10n.delete)),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  String _scheduleLabel(BuildContext context, Habit habit) {
    switch (habit.schedule) {
      case RepeatPattern.daily:
        return context.tr('scheduleDaily');
      case RepeatPattern.weekly:
        return context.tr('scheduleWeekly');
      case RepeatPattern.customDays:
        return context.tr('scheduleCustom');
      case RepeatPattern.none:
        return context.tr('none');
    }
  }
}

class _HabitDialog extends StatefulWidget {
  const _HabitDialog({required this.userId, this.habit});

  final String userId;
  final Habit? habit;

  @override
  State<_HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<_HabitDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late RepeatPattern _schedule;
  late Set<int> _days;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    _name = TextEditingController(text: habit?.name ?? '');
    _description = TextEditingController(text: habit?.description ?? '');
    _schedule = habit?.schedule ?? RepeatPattern.daily;
    _days = (habit?.customDays ?? const <int>[]).toSet();
    _active = habit?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final monday = DateTime(2024, 1, 1);
    return AlertDialog(
      title: Text(widget.habit == null ? context.tr('addHabit') : l10n.edit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: widget.habit == null,
              decoration: InputDecoration(labelText: context.tr('habitName')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.tr('habitDescription')),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<RepeatPattern>(
              initialValue: _schedule,
              decoration: InputDecoration(labelText: context.tr('habitSchedule')),
              items: <DropdownMenuItem<RepeatPattern>>[
                DropdownMenuItem<RepeatPattern>(
                  value: RepeatPattern.daily,
                  child: Text(context.tr('scheduleDaily')),
                ),
                DropdownMenuItem<RepeatPattern>(
                  value: RepeatPattern.weekly,
                  child: Text(context.tr('scheduleWeekly')),
                ),
                DropdownMenuItem<RepeatPattern>(
                  value: RepeatPattern.customDays,
                  child: Text(context.tr('scheduleCustom')),
                ),
              ],
              onChanged: (value) => setState(() => _schedule = value ?? RepeatPattern.daily),
            ),
            if (_schedule != RepeatPattern.daily) ...<Widget>[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.tr('days'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List<int>.generate(7, (i) => i + 1).map((day) {
                  final label = DateFormat.E(locale).format(monday.add(Duration(days: day - 1)));
                  final selected = _days.contains(day);
                  return GlowChoiceChip(
                    label: label,
                    selected: selected,
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _days.remove(day);
                        } else {
                          _days.add(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: Text(context.tr('activeHabit')),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final existing = widget.habit;
            Navigator.of(context).pop(
              Habit(
                id: existing?.id ?? uniqueId(),
                userId: widget.userId,
                name: name,
                description: _description.text.trim().isEmpty ? null : _description.text.trim(),
                schedule: _schedule,
                customDays: _days.toList()..sort(),
                isActive: _active,
                createdAt: existing?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
                syncStatus: SyncStatus.local,
                lastModified: DateTime.now(),
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
