/// المهام والتقويم: عرض يومي، إضافة وتعديل وحذف، وحفظ محلي.
library glowara.feature.calendar.tasks_screen;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:intl/intl.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _didLoad = false;
  bool _loading = true;
  DateTime _selectedDay = startOfDay(DateTime.now());
  List<TaskItem> _tasks = <TaskItem>[];
  List<TaskItem> _overdue = <TaskItem>[];

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
    final tasks = await state.tasks.forDay(state.userId, _selectedDay);
    final overdue = isToday(_selectedDay) ? await state.tasks.overdue(state.userId) : <TaskItem>[];
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _overdue = overdue.where((t) => dateKey(t.dueDateTime!) != dateKey(_selectedDay)).toList();
      _loading = false;
    });
  }

  Future<void> _toggle(TaskItem task) async {
    final state = AppState.of(context);
    await state.tasks.toggle(task);
    if (mounted) _load();
  }

  Future<void> _openEditor([TaskItem? task]) async {
    final state = AppState.of(context);
    final result = await showDialog<TaskItem>(
      context: context,
      builder: (_) => _TaskDialog(
        userId: state.userId,
        task: task,
        initialDay: _selectedDay,
      ),
    );
    if (result == null || !mounted) return;
    await state.tasks.save(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('taskSaved'))),
    );
    _load();
  }

  Future<void> _delete(TaskItem task) async {
    final ok = await showConfirmDialog(
      context,
      title: context.l10n.confirmDelete,
      message: context.l10n.confirmDeleteSub,
    );
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.tasks.delete(task.id);
    if (mounted) _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDay = startOfDay(picked);
      _loading = true;
    });
    _load();
  }

  String _categoryLabel(BuildContext context, String? category) {
    switch (category) {
      case 'personal':
        return context.tr('categoryPersonal');
      case 'study':
        return context.tr('categoryStudy');
      case 'work':
        return context.tr('categoryWork');
      case 'health':
        return context.tr('categoryHealth');
      case 'other':
        return context.tr('categoryOther');
      default:
        return '';
    }
  }

  String _priorityLabel(BuildContext context, int priority) {
    switch (priority) {
      case 3:
        return context.tr('priorityHigh');
      case 2:
        return context.tr('priorityMedium');
      default:
        return context.tr('priorityLow');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final locale = Localizations.localeOf(context).languageCode;
    final monday = startOfWeek(_selectedDay);

    return GlowPage(
      title: l10n.tasks,
      actions: <Widget>[
        IconButton(
          onPressed: () {
            setState(() {
              _selectedDay = startOfDay(DateTime.now());
              _loading = true;
            });
            _load();
          },
          icon: const Icon(Icons.today),
          tooltip: context.tr('todayTab'),
        ),
        IconButton(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month),
          tooltip: context.tr('selectDate'),
        ),
      ],
      child: Column(
        children: <Widget>[
          GlowCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: List<Widget>.generate(7, (index) {
                final day = monday.add(Duration(days: index));
                final selected = isSameDay(day, _selectedDay);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = day;
                        _loading = true;
                      });
                      _load();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? c.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            DateFormat.E(locale).format(day),
                            style: TextStyle(
                              fontSize: 9.5,
                              color: selected ? c.onPrimary : c.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: selected ? c.onPrimary : c.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.only(bottom: 90),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  formatFullDate(_selectedDay, locale),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: c.onSurface,
                                  ),
                                ),
                                Text(
                                  context.tr('tasksForDay'),
                                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _openEditor(),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(context.tr('addTask')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_overdue.isNotEmpty) ...<Widget>[
                        GlowSectionTitle(
                          title: context.tr('overdue'),
                          icon: Icons.schedule,
                        ),
                        ..._overdue.map((task) {
                          return GlowCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Checkbox(
                                value: task.state == TaskState.done,
                                onChanged: (_) => _toggle(task),
                              ),
                              title: Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: c.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                task.dueDateTime == null
                                    ? context.tr('overdue')
                                    : '${context.tr('overdue')} • ${formatShortDate(task.dueDateTime!, locale)}',
                                style: TextStyle(fontSize: 11, color: c.warning),
                              ),
                              onTap: () => _openEditor(task),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],
                      if (_tasks.isEmpty)
                        GlowEmptyState(
                          icon: Icons.task_alt,
                          title: context.tr('noTasksForDay'),
                          subtitle: context.tr('addTaskHint'),
                          actionLabel: context.tr('addTask'),
                          onAction: () => _openEditor(),
                        )
                      else
                        ..._tasks.map((task) {
                          final done = task.state == TaskState.done;
                          final time = task.dueDateTime;
                          final hasTime = time != null && (time.hour != 0 || time.minute != 0);
                          return GlowCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Checkbox(
                                      value: done,
                                      onChanged: (_) => _toggle(task),
                                    ),
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                          color: done ? c.onSurfaceVariant : c.onSurface,
                                          decoration: done ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') _openEditor(task);
                                        if (value == 'delete') _delete(task);
                                      },
                                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                                        PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Text(l10n.edit),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text(l10n.delete),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (task.description != null && task.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(start: 12, end: 8, bottom: 6),
                                    child: Text(
                                      task.description!,
                                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant, height: 1.5),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(start: 12, end: 8, bottom: 4),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: <Widget>[
                                      if (hasTime)
                                        _TaskMeta(
                                          icon: Icons.schedule,
                                          label: formatTime(time!, locale),
                                        ),
                                      if (task.category != null && task.category!.isNotEmpty)
                                        _TaskMeta(
                                          icon: Icons.label_outline,
                                          label: _categoryLabel(context, task.category),
                                        ),
                                      _TaskMeta(
                                        icon: Icons.flag_outlined,
                                        label: _priorityLabel(context, task.priority),
                                        color: task.priority >= 3 ? c.danger : c.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskMeta extends StatelessWidget {
  const _TaskMeta({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final tint = color ?? c.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: tint),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10.5, color: tint)),
      ],
    );
  }
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.userId, required this.initialDay, this.task});

  final String userId;
  final DateTime initialDay;
  final TaskItem? task;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late DateTime _day;
  TimeOfDay? _time;
  String? _category;
  int _priority = 1;
  RepeatPattern _repeat = RepeatPattern.none;
  final Set<int> _customDays = <int>{};

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _description = TextEditingController(text: task?.description ?? '');
    final due = task?.dueDateTime;
    _day = due == null ? widget.initialDay : startOfDay(due);
    if (due != null && (due.hour != 0 || due.minute != 0)) {
      _time = TimeOfDay(hour: due.hour, minute: due.minute);
    }
    _category = task?.category;
    _priority = task?.priority ?? 1;
    _repeat = task?.repeat ?? RepeatPattern.none;
    _customDays.addAll(task?.customDays ?? const <int>[]);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _day = startOfDay(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final now = DateTime.now();
    final existing = widget.task;
    final due = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _time?.hour ?? 0,
      _time?.minute ?? 0,
    );
    final repeat = _repeat == RepeatPattern.customDays && _customDays.isEmpty
        ? RepeatPattern.none
        : _repeat;
    Navigator.of(context).pop(
      TaskItem(
        id: existing?.id ?? uniqueId(),
        userId: widget.userId,
        title: title,
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        dueDateTime: due,
        category: _category,
        priority: _priority,
        state: existing?.state ?? TaskState.open,
        repeat: repeat,
        customDays: repeat == RepeatPattern.customDays
            ? (_customDays.toList()..sort())
            : const <int>[],
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        syncStatus: SyncStatus.local,
        lastModified: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    return AlertDialog(
      title: Text(widget.task == null ? context.tr('addTask') : context.tr('editTask')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _title,
              autofocus: widget.task == null,
              decoration: InputDecoration(labelText: context.tr('taskTitle')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.tr('taskDescription')),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.date,
                  suffixIcon: const Icon(Icons.event),
                ),
                child: Text(formatFullDate(_day, locale)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.tr('taskTime'),
                        suffixIcon: const Icon(Icons.schedule),
                      ),
                      child: Text(
                        _time == null ? context.l10n.none : _time!.format(context),
                      ),
                    ),
                  ),
                ),
                if (_time != null)
                  IconButton(
                    onPressed: () => setState(() => _time = null),
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: context.tr('clearTime'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(labelText: context.tr('taskCategory')),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'personal', child: Text(context.tr('categoryPersonal'))),
                DropdownMenuItem<String>(value: 'study', child: Text(context.tr('categoryStudy'))),
                DropdownMenuItem<String>(value: 'work', child: Text(context.tr('categoryWork'))),
                DropdownMenuItem<String>(value: 'health', child: Text(context.tr('categoryHealth'))),
                DropdownMenuItem<String>(value: 'other', child: Text(context.tr('categoryOther'))),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<RepeatPattern>(
              value: _repeat,
              decoration: InputDecoration(labelText: context.tr('repeat')),
              items: <DropdownMenuItem<RepeatPattern>>[
                DropdownMenuItem<RepeatPattern>(
                  value: RepeatPattern.none,
                  child: Text(context.tr('repeatNone')),
                ),
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
              onChanged: (value) => setState(() => _repeat = value ?? RepeatPattern.none),
            ),
            if (_repeat == RepeatPattern.customDays) ...<Widget>[
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
                children: List<int>.generate(7, (i) => i + 1).map((weekday) {
                  // 1 يناير 2024 كان يوم اثنين، لذا weekday=1 => Monday.
                  final label = DateFormat.E(locale).format(
                    DateTime(2024, 1, 1).add(Duration(days: weekday - 1)),
                  );
                  final selected = _customDays.contains(weekday);
                  return GlowChoiceChip(
                    label: label,
                    selected: selected,
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _customDays.remove(weekday);
                        } else {
                          _customDays.add(weekday);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.tr('priority'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: <ButtonSegment<int>>[
                ButtonSegment<int>(value: 1, label: Text(context.tr('priorityLow'))),
                ButtonSegment<int>(value: 2, label: Text(context.tr('priorityMedium'))),
                ButtonSegment<int>(value: 3, label: Text(context.tr('priorityHigh'))),
              ],
              selected: <int>{_priority},
              onSelectionChanged: (value) => setState(() => _priority = value.first),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
