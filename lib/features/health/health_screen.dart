/// الصحة: الماء والوجبات.
library glowara.feature.health;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  bool _didLoad = false;
  bool _loading = true;
  int _waterMl = 0;
  List<MealNote> _meals = <MealNote>[];

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
    final water = await state.health.waterTotal(state.userId, now);
    final meals = await state.health.meals(state.userId, from: now, to: now);
    if (!mounted) return;
    setState(() {
      _waterMl = water;
      _meals = meals;
      _loading = false;
    });
  }

  Future<void> _addWater(int delta) async {
    final state = AppState.of(context);
    await state.health.addWater(userId: state.userId, day: DateTime.now(), deltaMl: delta);
    if (mounted) _load();
  }

  Future<void> _editGoal() async {
    final state = AppState.of(context);
    final controller = TextEditingController(text: state.waterGoalMl.toString());
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('waterGoal')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.tr('waterGoal'),
            suffixText: context.tr('mlShort'),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (result != true || !mounted) {
      controller.dispose();
      return;
    }
    final value = int.tryParse(controller.text.trim());
    controller.dispose();
    if (value != null && value > 0) {
      await state.setWaterGoalMl(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('goalUpdated'))),
        );
        _load();
      }
    }
  }

  Future<void> _editCupSize() async {
    final state = AppState.of(context);
    final controller = TextEditingController(text: state.cupSizeMl.toString());
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('editCupSize')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.tr('cupSize'),
            suffixText: context.tr('mlShort'),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (result != true || !mounted) {
      controller.dispose();
      return;
    }
    final value = int.tryParse(controller.text.trim());
    controller.dispose();
    if (value != null && value > 0) {
      await state.setCupSizeMl(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('cupUpdated'))),
        );
      }
    }
  }

  Future<void> _toggleReminder(bool value) async {
    final state = AppState.of(context);
    await state.setReminders(state.reminders.copyWith(waterEnabled: value));
    if (mounted) setState(() {});
  }

  String _mealLabel(BuildContext context, String type) {
    switch (type) {
      case 'breakfast':
        return context.tr('breakfast');
      case 'lunch':
        return context.tr('lunch');
      case 'dinner':
        return context.tr('dinner');
      case 'snack':
        return context.tr('snack');
      default:
        return context.tr('otherMeal');
    }
  }

  Future<void> _openMealEditor([MealNote? meal]) async {
    final state = AppState.of(context);
    final note = TextEditingController(text: meal?.note ?? '');
    var type = meal?.mealType ?? 'meal';
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(meal == null ? context.tr('addMeal') : l10n.edit),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(labelText: context.tr('mealType')),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'breakfast', child: Text(context.tr('breakfast'))),
                  DropdownMenuItem<String>(value: 'lunch', child: Text(context.tr('lunch'))),
                  DropdownMenuItem<String>(value: 'dinner', child: Text(context.tr('dinner'))),
                  DropdownMenuItem<String>(value: 'snack', child: Text(context.tr('snack'))),
                  DropdownMenuItem<String>(value: 'meal', child: Text(context.tr('otherMeal'))),
                ],
                onChanged: (value) => setDialogState(() => type = value ?? 'meal'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: InputDecoration(labelText: context.tr('mealNote')),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) {
      note.dispose();
      return;
    }
    final noteText = note.text.trim();
    note.dispose();
    final now = DateTime.now();
    await state.health.saveMeal(
      MealNote(
        id: meal?.id ?? uniqueId(),
        userId: state.userId,
        dateTime: meal?.dateTime ?? now,
        mealType: type,
        note: noteText.isEmpty ? null : noteText,
        createdAt: meal?.createdAt ?? now,
        syncStatus: SyncStatus.local,
        lastModified: now,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('mealSaved'))),
      );
      _load();
    }
  }

  Future<void> _deleteMeal(MealNote meal) async {
    final ok = await showConfirmDialog(context, title: context.l10n.confirmDelete);
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.health.deleteMeal(meal.id);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final state = AppState.of(context);
    final goal = state.waterGoalMl;
    final locale = Localizations.localeOf(context).languageCode;

    return DefaultTabController(
      length: 2,
      child: GlowPage(
        title: context.tr('healthTitle'),
        padding: EdgeInsets.zero,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  TabBar(
                    labelColor: c.primary,
                    unselectedLabelColor: c.onSurfaceVariant,
                    indicatorColor: c.primary,
                    tabs: <Widget>[
                      Tab(icon: const Icon(Icons.water_drop_outlined), text: context.tr('waterTitle')),
                      Tab(icon: const Icon(Icons.restaurant_outlined), text: context.tr('mealsTitle')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: <Widget>[
                            GlowCard(
                              child: Column(
                                children: <Widget>[
                                  SizedBox(
                                    width: 150,
                                    height: 150,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: <Widget>[
                                        SizedBox(
                                          width: 150,
                                          height: 150,
                                          child: CircularProgressIndicator(
                                            value: goal == 0 ? 0.0 : (_waterMl / goal).clamp(0.0, 1.0).toDouble(),
                                            strokeWidth: 10,
                                            backgroundColor: c.primaryContainer,
                                            valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Text(
                                              '$_waterMl',
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w800,
                                                color: c.onSurface,
                                              ),
                                            ),
                                            Text(
                                              '/ $goal ${context.tr('mlShort')}',
                                              style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _waterMl >= goal
                                        ? context.tr('waterGoalReached')
                                        : context.tr('todayWater'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _waterMl >= goal ? c.success : c.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      OutlinedButton.icon(
                                        onPressed: () => _addWater(-state.cupSizeMl),
                                        icon: const Icon(Icons.remove, size: 18),
                                        label: Text(context.tr('removeCup')),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton.icon(
                                        onPressed: () => _addWater(state.cupSizeMl),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: Text(context.tr('addCup')),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 4,
                                    children: <Widget>[
                                      Text(
                                        '${context.tr('cupSize')}: ${state.cupSizeMl} ${context.tr('mlShort')}',
                                        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                                      ),
                                      TextButton(
                                        onPressed: _editCupSize,
                                        child: Text(context.tr('editCupSize')),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: _editGoal,
                                    icon: const Icon(Icons.flag_outlined, size: 16),
                                    label: Text(context.tr('editGoal')),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            GlowCard(
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: state.reminders.waterEnabled,
                                onChanged: _toggleReminder,
                                title: Text(
                                  context.tr('waterReminder'),
                                  style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                                ),
                                subtitle: Text(
                                  context.tr('waterReminderSub'),
                                  style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.tr('flexibleHealthNote'),
                              style: TextStyle(fontSize: 11, color: c.onSurfaceVariant, height: 1.5),
                            ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    context.tr('mealsTitle'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _openMealEditor(),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(context.tr('addMeal')),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_meals.isEmpty)
                              GlowEmptyState(
                                icon: Icons.restaurant_outlined,
                                title: context.tr('noMeals'),
                                subtitle: context.tr('noMealsSub'),
                                actionLabel: context.tr('addMeal'),
                                onAction: () => _openMealEditor(),
                              )
                            else
                              ..._meals.map((meal) {
                                return GlowCard(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: c.primaryContainer,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(Icons.restaurant, size: 18, color: c.primary),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              _mealLabel(context, meal.mealType),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: c.onSurface,
                                              ),
                                            ),
                                            Text(
                                              formatTime(meal.dateTime, locale),
                                              style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                                            ),
                                            if (meal.note != null && meal.note!.isNotEmpty)
                                              Text(
                                                meal.note!,
                                                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _openMealEditor(meal),
                                        icon: Icon(Icons.edit_outlined, size: 18, color: c.onSurfaceVariant),
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteMeal(meal),
                                        icon: Icon(Icons.delete_outline, size: 18, color: c.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('flexibleHealthNote'),
                              style: TextStyle(fontSize: 11, color: c.onSurfaceVariant, height: 1.5),
                            ),
                          ],
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
