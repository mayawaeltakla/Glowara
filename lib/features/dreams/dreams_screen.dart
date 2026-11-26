/// أحلامي: قائمة الأحلام بمرحلتها وموعدها وعدد خطواتها. بلا نسب ولا تنبيهات.
library glowara.feature.dreams;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/dream_models.dart';
import 'package:glowara/core/repositories/dream_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:go_router/go_router.dart';

String dreamStageKey(String stage) {
  switch (stage) {
    case 'planning':
      return 'drStagePlanning';
    case 'working':
      return 'drStageWorking';
    case 'achieved':
      return 'drStageAchieved';
    default:
      return 'drStageDreaming';
  }
}

/// «2 من 5 خطوات» (عدد فقط، بلا نسبة).
String dreamStepsLine(BuildContext context, Dream d) => context
    .tr('drStepsCount')
    .replaceAll('{d}', '${d.stepsDone}')
    .replaceAll('{t}', '${d.steps.length}');

class DreamsScreen extends StatefulWidget {
  const DreamsScreen({super.key});

  @override
  State<DreamsScreen> createState() => _DreamsScreenState();
}

class _DreamsScreenState extends State<DreamsScreen> {
  bool _didLoad = false;
  bool _loading = true;
  Object? _error;
  List<Dream> _dreams = const <Dream>[];

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
      final list = await DreamRepository(state.db).all(state.userId);
      if (!mounted) return;
      setState(() {
        _dreams = list;
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
    await context.push('/dreams/dream/$id');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final locale = AppState.of(context).locale;
    return GlowPage(
      title: context.tr('drTitle'),
      fab: FloatingActionButton.extended(
        key: const Key('dr-add'),
        onPressed: () => _open('new'),
        icon: const Icon(Icons.add),
        label: Text(context.tr('drAdd')),
      ),
      child: _error != null
          ? GlowErrorView(message: context.tr('drLoadError'), onRetry: _load)
          : ListView(
              children: <Widget>[
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Text(
                  context.tr('drNote'),
                  key: const Key('dr-note'),
                  style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 12),
                if (!_loading && _dreams.isEmpty)
                  Text(context.tr('drEmpty'), key: const Key('dr-empty'), style: TextStyle(color: c.onSurfaceVariant)),
                for (final d in _dreams)
                  GlowCard(
                    key: Key('dr-item-${d.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _open(d.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(d.title, style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                          Text(
                            <String>[
                              context.tr(dreamStageKey(d.stage)),
                              if (d.steps.isNotEmpty) dreamStepsLine(context, d),
                              if (d.targetDate != null && DateTime.tryParse(d.targetDate!) != null)
                                formatShortDate(DateTime.parse(d.targetDate!), locale),
                            ].join(' · '),
                            style: TextStyle(fontSize: 12, color: c.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 72),
              ],
            ),
    );
  }
}
