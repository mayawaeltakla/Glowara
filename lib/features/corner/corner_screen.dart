/// ركني الصغير: قائمة المدخلات. المختومة لا يظهر نصها حتى يحين تاريخها.
library glowara.feature.corner;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/corner_models.dart';
import 'package:glowara/core/repositories/corner_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:go_router/go_router.dart';

String cornerKindKey(String kind) {
  switch (kind) {
    case 'memory':
      return 'cnMemory';
    case 'wish':
      return 'cnWish';
    default:
      return 'cnLetter';
  }
}

class CornerScreen extends StatefulWidget {
  const CornerScreen({super.key});

  @override
  State<CornerScreen> createState() => _CornerScreenState();
}

class _CornerScreenState extends State<CornerScreen> {
  bool _didLoad = false;
  bool _loading = true;
  Object? _error;
  List<CornerEntry> _entries = const <CornerEntry>[];
  String? _kind;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    try {
      final list = await CornerRepository(state.db).all(state.userId);
      if (!mounted) return;
      setState(() {
        _entries = list;
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

  Future<void> _open(String id) async {
    await context.push('/corner/entry/$id');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final locale = AppState.of(context).locale;
    final today = dateKey(DateTime.now());
    final shown = _entries.where((e) => _kind == null || e.kind == _kind).toList();
    return GlowPage(
      title: context.tr('cnTitle'),
      fab: FloatingActionButton.extended(
        key: const Key('cn-add'),
        onPressed: () => _open('new'),
        icon: const Icon(Icons.add),
        label: Text(context.tr('cnAdd')),
      ),
      child: _error != null
          ? GlowErrorView(message: context.tr('cnLoadError'), onRetry: _load)
          : ListView(
              children: <Widget>[
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Text(
                  context.tr('cnNote'),
                  key: const Key('cn-note'),
                  style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 12),
                if (_entries.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      ChoiceChip(
                        key: const Key('cn-kind-all'),
                        label: Text(context.tr('cnAll')),
                        selected: _kind == null,
                        onSelected: (_) => setState(() => _kind = null),
                      ),
                      for (final k in kCornerKinds)
                        ChoiceChip(
                          key: Key('cn-kind-$k'),
                          label: Text(context.tr(cornerKindKey(k))),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (!_loading && _entries.isEmpty)
                  Text(context.tr('cnEmpty'), key: const Key('cn-empty'), style: TextStyle(color: c.onSurfaceVariant)),
                for (final e in shown) _card(e, c, today, locale),
                const SizedBox(height: 72),
              ],
            ),
    );
  }

  Widget _card(CornerEntry e, GlowColors c, String today, String locale) {
    final sealed = e.isSealed(today);
    final head = e.title.isNotEmpty ? e.title : context.tr('cnUntitled');
    final openDate = e.openOn == null ? null : DateTime.tryParse(e.openOn!);
    return GlowCard(
      key: Key('cn-item-${e.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _open(e.id),
        child: Row(
          children: <Widget>[
            Icon(sealed ? Icons.lock_outline : Icons.mail_outline, size: 20, color: c.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(head, style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                  Text(
                    sealed && openDate != null
                        ? '${context.tr(cornerKindKey(e.kind))} · ${context.tr('cnSealed')} ${formatShortDate(openDate, locale)}'
                        : context.tr(cornerKindKey(e.kind)),
                    style: TextStyle(fontSize: 12, color: c.primary),
                  ),
                  // نص المختومة لا يظهر في القائمة أبدًا.
                  if (!sealed)
                    Text(
                      e.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
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
