/// مدخل في ركني: كتابة وتعديل. المختوم يعرض بطاقة ختم حتى يحين تاريخه أو تطلب فتحه.
library glowara.feature.corner_entry;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/corner_models.dart';
import 'package:glowara/core/repositories/corner_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/corner/corner_screen.dart';

class CornerEntryScreen extends StatefulWidget {
  /// [entryId] = 'new' لمدخل جديد.
  const CornerEntryScreen({super.key, required this.entryId});

  final String entryId;

  @override
  State<CornerEntryScreen> createState() => _CornerEntryScreenState();
}

class _CornerEntryScreenState extends State<CornerEntryScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _text = TextEditingController();
  String _kind = 'letter';
  String? _openOn;
  CornerEntry? _entry;
  bool _didLoad = false;
  bool _loading = true;
  bool _missing = false;

  /// فتحٌ مبكر بطلبها، لهذه الجلسة فقط ولا يُحفظ.
  bool _openedEarly = false;

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
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.entryId != 'new') {
      final state = AppState.of(context);
      final e = await CornerRepository(state.db).byId(state.userId, widget.entryId);
      if (!mounted) return;
      if (e == null) {
        setState(() {
          _missing = true;
          _loading = false;
        });
        return;
      }
      _entry = e;
      _title.text = e.title;
      _text.text = e.text;
      _kind = e.kind;
      _openOn = e.openOn;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _msg(String key) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null && mounted) setState(() => _openOn = dateKey(picked));
  }

  Future<void> _save() async {
    final state = AppState.of(context);
    if (_text.text.trim().isEmpty) {
      _msg('cnTextRequired');
      return;
    }
    try {
      await CornerRepository(state.db).save(
        userId: state.userId,
        id: _entry?.id,
        kind: _kind,
        title: _title.text,
        text: _text.text,
        openOn: _openOn,
      );
    } on StateError {
      if (mounted) _msg('cnLimit');
      return;
    }
    if (!mounted) return;
    _msg('cnSaved');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final state = AppState.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(context.tr('cnDeleteConfirm')),
        actions: <Widget>[
          TextButton(key: const Key('cn-delete-no'), onPressed: () => Navigator.of(d).pop(false), child: Text(context.tr('cancel'))),
          FilledButton(key: const Key('cn-delete-yes'), onPressed: () => Navigator.of(d).pop(true), child: Text(context.tr('cnDelete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await CornerRepository(state.db).delete(state.userId, _entry!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppState.of(context).locale;
    final c = Theme.of(context).colorScheme;
    final sealed = _entry != null && _entry!.isSealed(dateKey(DateTime.now())) && !_openedEarly;
    final openDate = _openOn == null ? null : DateTime.tryParse(_openOn!);
    return GlowPage(
      title: context.tr(widget.entryId == 'new' ? 'cnNewTitle' : 'cnEdit'),
      child: _missing
          ? Center(child: Text(context.tr('cnNotFound'), key: const Key('cn-missing')))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : sealed
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.lock_outline, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          '${context.tr('cnSealed')} ${openDate == null ? '' : formatShortDate(openDate, locale)}',
                          key: const Key('cn-sealed'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(context.tr('cnSealedBody'), textAlign: TextAlign.center, style: TextStyle(color: c.onSurfaceVariant)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          key: const Key('cn-open-now'),
                          onPressed: () => setState(() => _openedEarly = true),
                          child: Text(context.tr('cnOpenNow')),
                        ),
                      ],
                    )
                  : ListView(
                      children: <Widget>[
                        Text(context.tr('cnKind')),
                        Wrap(
                          spacing: 8,
                          children: <Widget>[
                            for (final k in kCornerKinds)
                              ChoiceChip(
                                key: Key('cn-set-$k'),
                                label: Text(context.tr(cornerKindKey(k))),
                                selected: _kind == k,
                                onSelected: (_) => setState(() => _kind = k),
                              ),
                          ],
                        ),
                        TextField(
                          key: const Key('cn-title'),
                          controller: _title,
                          maxLength: kCornerTitleMax,
                          decoration: InputDecoration(labelText: context.tr('cnEntryTitle'), counterText: ''),
                        ),
                        TextField(
                          key: const Key('cn-text'),
                          controller: _text,
                          maxLines: 8,
                          maxLength: kCornerTextMax,
                          decoration: InputDecoration(labelText: context.tr('cnText')),
                        ),
                        const SizedBox(height: 8),
                        Text(context.tr('cnOpenOn')),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                openDate == null ? context.tr('cnNoDate') : formatShortDate(openDate, locale),
                                key: const Key('cn-open-on'),
                              ),
                            ),
                            TextButton(key: const Key('cn-pick-date'), onPressed: _pickDate, child: Text(context.tr('cnPickDate'))),
                            if (_openOn != null)
                              TextButton(
                                key: const Key('cn-clear-date'),
                                onPressed: () => setState(() => _openOn = null),
                                child: Text(context.tr('cnClearDate')),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(key: const Key('cn-save'), onPressed: _save, child: Text(context.tr('save'))),
                        if (_entry != null)
                          TextButton(key: const Key('cn-delete'), onPressed: _delete, child: Text(context.tr('cnDelete'))),
                      ],
                    ),
    );
  }
}
