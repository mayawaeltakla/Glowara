/// الإعدادات: الحساب، اللغة، الثيم، التذكيرات، الخصوصية والبيانات.
library glowara.feature.settings;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _didLoad = false;
  int _bytes = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _loadSize();
    }
  }

  Future<void> _loadSize() async {
    final state = AppState.of(context);
    final bytes = await state.storageBytes();
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  Future<void> _editName() async {
    final state = AppState.of(context);
    final controller = TextEditingController(text: state.user?.displayName ?? '');
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('displayName')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.tr('displayName')),
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
    final name = controller.text.trim();
    controller.dispose();
    await state.updateDisplayName(name);
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('logoutConfirm'),
      confirmLabel: context.l10n.logout,
    );
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.logout();
    if (mounted) context.go('/');
  }

  Future<void> _deleteAccount() async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('deleteAccountConfirm'),
      message: context.tr('deleteAccountSub'),
    );
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.deleteAccount();
    if (mounted) context.go('/');
  }

  Future<void> _saveReminders(ReminderSettings value) async {
    final state = AppState.of(context);
    await state.setReminders(value);
    if (mounted) setState(() {});
  }

  Future<void> _saveDisplay(DisplaySettings value) async {
    final state = AppState.of(context);
    await state.setDisplay(value);
    if (mounted) setState(() {});
  }

  Future<void> _setPinFlow() async {
    final state = AppState.of(context);
    if (state.pinSet) {
      final current = await showDialog<String>(
        context: context,
        builder: (_) => const _PinDialog(titleKey: 'enterPin', confirm: false),
      );
      if (current == null || !mounted) return;
      final valid = await state.verifyPin(current);
      if (!valid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('wrongPin'))),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _PinDialog(titleKey: 'setPin', confirm: true),
    );
    if (pin == null || !mounted) return;
    await state.setPin(pin);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pinEnabled'))),
      );
      setState(() {});
    }
  }

  Future<void> _removePin() async {
    final state = AppState.of(context);
    final current = await showDialog<String>(
      context: context,
      builder: (_) => const _PinDialog(titleKey: 'enterPin', confirm: false),
    );
    if (current == null || !mounted) return;
    final valid = await state.verifyPin(current);
    if (!valid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('wrongPin'))),
        );
      }
      return;
    }
    await state.removePin();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pinDisabled'))),
      );
      setState(() {});
    }
  }

  Future<void> _exportData() async {
    final state = AppState.of(context);
    final data = await state.exportData();
    await Clipboard.setData(ClipboardData(text: data));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('copied'))),
    );
  }

  Future<void> _importData() async {
    final state = AppState.of(context);
    final controller = TextEditingController();
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('importData')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                context.tr('importHint'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(hintText: '{ ... }'),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      setDialogState(() => controller.text = data!.text!);
                    }
                  },
                  icon: const Icon(Icons.paste, size: 16),
                  label: Text(context.tr('paste')),
                ),
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
              child: Text(context.tr('import')),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) {
      controller.dispose();
      return;
    }
    final source = controller.text;
    controller.dispose();
    try {
      await state.importData(source);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('importSuccess'))),
      );
      _loadSize();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('importError'))),
      );
    }
  }

  Future<void> _clearData() async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('clearData'),
      message: context.tr('clearDataConfirm'),
    );
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.clearAllData();
    if (mounted) context.go('/');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} ${context.tr('storageUnitKB')}';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} ${context.tr('storageUnitMB')}';
  }

  String _paletteName(BuildContext context, String id) {
    switch (id) {
      case 'lilac':
        return context.tr('themeLilac');
      case 'sand':
        return context.tr('themeSand');
      default:
        return context.tr('themeRose');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final state = AppState.of(context);
    final reminders = state.reminders;
    final display = state.display;

    return GlowPage(
      title: l10n.settings,
      actions: <Widget>[
        IconButton(onPressed: _loadSize, icon: const Icon(Icons.refresh)),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          _Section(
            title: context.tr('account'),
            children: <Widget>[
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: c.primaryContainer,
                  child: Text(
                    (state.user?.displayName?.trim().isNotEmpty ?? false)
                        ? state.user!.displayName!.trim().substring(0, 1)
                        : 'G',
                    style: TextStyle(color: c.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(state.user?.displayName ?? l10n.name),
                subtitle: Text(state.user?.email ?? ''),
                trailing: IconButton(
                  onPressed: _editName,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  context.tr('accountLocalNote'),
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant, height: 1.5),
                ),
              ),
              ListTile(
                leading: Icon(Icons.logout, color: c.onSurfaceVariant),
                title: Text(l10n.logout),
                onTap: _logout,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: context.tr('languageSection'),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'ar', label: Text(l10n.arabic)),
                      ButtonSegment<String>(value: 'en', label: Text(l10n.english)),
                    ],
                    selected: <String>{state.locale},
                    onSelectionChanged: (value) async {
                      await state.setLocale(value.first);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: context.tr('themeSection'),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode, size: 16),
                        label: Text(l10n.light),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode, size: 16),
                        label: Text(l10n.dark),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.phone_android, size: 16),
                        label: Text(l10n.system),
                      ),
                    ],
                    selected: <ThemeMode>{state.themeMode},
                    onSelectionChanged: (value) async {
                      await state.setTheme(state.themeId, value.first);
                    },
                  ),
                ),
              ),
              ...AppThemes.ids().map((id) {
                final palette = AppThemes.palette(id);
                final selected = state.themeId == id;
                return ListTile(
                  leading: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: palette.light.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.light.gold, width: 2),
                    ),
                  ),
                  title: Text(_paletteName(context, id)),
                  trailing: selected
                      ? Icon(Icons.check_circle, color: c.primary, size: 20)
                      : Icon(Icons.circle_outlined, color: c.onSurfaceVariant, size: 20),
                  onTap: () async {
                    await state.setTheme(id, state.themeMode);
                  },
                );
              }),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: context.tr('remindersTitle'),
            children: <Widget>[
              SwitchListTile(
                value: reminders.waterEnabled,
                onChanged: (value) => _saveReminders(reminders.copyWith(waterEnabled: value)),
                title: Text(context.tr('waterReminder')),
                subtitle: Text(
                  context.tr('waterReminderSub'),
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                ),
              ),
              SwitchListTile(
                value: reminders.quietHoursEnabled,
                onChanged: (value) => _saveReminders(reminders.copyWith(quietHoursEnabled: value)),
                title: Text(context.tr('quietHours')),
              ),
              if (reminders.quietHoursEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: reminders.quietStartHour,
                          decoration: InputDecoration(labelText: context.tr('quietFrom')),
                          items: List<int>.generate(24, (i) => i).map((hour) {
                            return DropdownMenuItem<int>(value: hour, child: Text('$hour:00'));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _saveReminders(reminders.copyWith(quietStartHour: value));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: reminders.quietEndHour,
                          decoration: InputDecoration(labelText: context.tr('quietTo')),
                          items: List<int>.generate(24, (i) => i).map((hour) {
                            return DropdownMenuItem<int>(value: hour, child: Text('$hour:00'));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _saveReminders(reminders.copyWith(quietEndHour: value));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  context.tr('reminderNote'),
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant, height: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: context.tr('displayPrefs'),
            children: <Widget>[
              SwitchListTile(
                value: display.showMotivation,
                onChanged: (value) => _saveDisplay(display.copyWith(showMotivation: value)),
                title: Text(context.tr('showMotivation')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: context.tr('privacySection'),
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.lock_outline, color: c.primary),
                title: Text(state.pinSet ? context.tr('pinStatusOn') : context.tr('pinStatusOff')),
                subtitle: Text(
                  context.tr('journalPrivateHint'),
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                ),
                trailing: TextButton(
                  onPressed: _setPinFlow,
                  child: Text(state.pinSet ? context.tr('changePin') : context.tr('setPin')),
                ),
              ),
              if (state.pinSet)
                ListTile(
                  leading: Icon(Icons.lock_open, color: c.onSurfaceVariant),
                  title: Text(context.tr('removePin')),
                  onTap: _removePin,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: context.tr('dataPrivacy'),
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.download_outlined, color: c.primary),
                title: Text(context.tr('exportData')),
                subtitle: Text(
                  context.tr('exportHint'),
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                ),
                onTap: _exportData,
              ),
              ListTile(
                leading: Icon(Icons.upload_outlined, color: c.primary),
                title: Text(context.tr('importData')),
                onTap: _importData,
              ),
              ListTile(
                leading: Icon(Icons.storage_outlined, color: c.onSurfaceVariant),
                title: Text(context.tr('storageSize')),
                trailing: Text(_formatBytes(_bytes)),
                onTap: _loadSize,
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: c.danger),
                title: Text(context.tr('clearData'), style: TextStyle(color: c.danger)),
                onTap: _clearData,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  '${context.tr('syncNote')}\n${context.tr('notificationsNote')}',
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant, height: 1.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: context.tr('dangerZone'),
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.person_remove, color: c.danger),
                title: Text(
                  context.l10n.deleteAccount,
                  style: TextStyle(color: c.danger),
                ),
                subtitle: Text(
                  context.tr('deleteAccountSub'),
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                ),
                onTap: _deleteAccount,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: context.tr('aboutTitle'),
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.info_outline, color: c.primary),
                title: Text(l10n.appTitle),
                subtitle: Text('${l10n.version} 1.0.0'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  context.tr('madeWith'),
                  style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 4, left: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
        ),
        GlowCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.titleKey, required this.confirm});

  final String titleKey;
  final bool confirm;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    final pin = _pin.text.trim();
    if (pin.length < 4) {
      setState(() => _error = context.tr('pinLengthError'));
      return;
    }
    if (widget.confirm && pin != _confirm.text.trim()) {
      setState(() => _error = context.tr('pinMismatch'));
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(context.tr(widget.titleKey)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.tr('enterPin'), errorText: _error),
          ),
          if (widget.confirm) ...<Widget>[
            const SizedBox(height: 10),
            TextField(
              controller: _confirm,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.confirmPassword),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
