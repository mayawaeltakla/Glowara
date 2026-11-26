/// فهم المزاج والطاقة: وصف هادئ لما سجّلتِه. لا تشخيص ولا أسباب ولا درجة.
library glowara.feature.insights;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/insights_models.dart';
import 'package:glowara/core/repositories/insights_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

const List<String> _moodKeys = <String>['moodBad', 'moodLow', 'moodOkay', 'moodGood', 'moodGreat'];
const List<String> _moodEmojis = <String>['😞', '😔', '😐', '🙂', '😄'];

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, this.today});

  /// لليوم الأخير في الفترة؛ الافتراضي اليوم الفعلي (للاختبار).
  final DateTime? today;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _didLoad = false;
  bool _loading = true;
  Object? _error;
  int _days = 30;
  bool _study = false;
  MoodInsights? _insights;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    setState(() => _loading = true);
    try {
      final r = await InsightsRepository(state.db).compute(
        state.userId,
        today: widget.today ?? DateTime.now(),
        days: _days,
        includeStudy: _study,
      );
      if (!mounted) return;
      setState(() {
        _insights = r;
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

  String _weekday(int weekday, String locale) => DateFormat.EEEE(locale).format(DateTime(2024, 1, weekday));

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final locale = AppState.of(context).locale;
    final r = _insights;
    return GlowPage(
      title: context.tr('inTitle'),
      child: _error != null
          ? GlowErrorView(message: context.tr('inLoadError'), onRetry: _load)
          : ListView(
              children: <Widget>[
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Text(
                  context.tr('inNote'),
                  key: const Key('in-note'),
                  style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    for (final d in const <int>[30, 90])
                      ChoiceChip(
                        key: Key('in-days-$d'),
                        label: Text(context.tr(d == 30 ? 'in30' : 'in90')),
                        selected: _days == d,
                        onSelected: (_) {
                          setState(() => _days = d);
                          _load();
                        },
                      ),
                  ],
                ),
                SwitchListTile(
                  key: const Key('in-study-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('inStudySwitch')),
                  subtitle: Text(context.tr('inStudySwitchSub'), style: const TextStyle(fontSize: 12)),
                  value: _study,
                  onChanged: (v) {
                    setState(() => _study = v);
                    _load();
                  },
                ),
                if (r != null) ...<Widget>[
                  GlowCard(
                    key: const Key('in-summary'),
                    child: Text(
                      context.tr('inRecorded').replaceAll('{n}', '${r.recordedDays}').replaceAll('{m}', '${r.periodDays}'),
                      style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                    ),
                  ),
                  if (r.recordedDays == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(context.tr('inEmpty'), key: const Key('in-empty'), style: TextStyle(color: c.onSurfaceVariant)),
                    )
                  else ...<Widget>[
                    const SizedBox(height: 12),
                    GlowSectionTitle(title: context.tr('inMoodTitle')),
                    _distribution(r.moodCounts, (i) => '${_moodEmojis[i - 1]} ${context.tr(_moodKeys[i - 1])}', 'mood', c),
                    if (r.energyRecordedDays > 0) ...<Widget>[
                      const SizedBox(height: 12),
                      GlowSectionTitle(title: context.tr('inEnergyTitle')),
                      _distribution(r.energyCounts, (i) => context.tr('eg$i'), 'energy', c),
                    ],
                    const SizedBox(height: 12),
                    GlowSectionTitle(title: context.tr('inPatternsTitle')),
                    if (!r.hasEnoughForPatterns)
                      Text(context.tr('inNeedMore'), key: const Key('in-need-more'), style: TextStyle(color: c.onSurfaceVariant, fontSize: 13))
                    else if (r.highestWeekday == null && r.lowestWeekday == null)
                      Text(context.tr('inNoPattern'), key: const Key('in-no-pattern'), style: TextStyle(color: c.onSurfaceVariant, fontSize: 13))
                    else ...<Widget>[
                      if (r.highestWeekday != null)
                        Text(
                          context.tr('inHighest').replaceAll('{d}', _weekday(r.highestWeekday!, locale)),
                          key: const Key('in-highest'),
                        ),
                      if (r.lowestWeekday != null)
                        Text(
                          context.tr('inLowest').replaceAll('{d}', _weekday(r.lowestWeekday!, locale)),
                          key: const Key('in-lowest'),
                        ),
                    ],
                    if (_study) ...<Widget>[
                      const SizedBox(height: 12),
                      GlowSectionTitle(title: context.tr('inStudyTitle')),
                      if (r.study == null)
                        Text(context.tr('inStudyNeedMore'), key: const Key('in-study-need-more'), style: TextStyle(color: c.onSurfaceVariant, fontSize: 13))
                      else ...<Widget>[
                        Text(
                          context
                              .tr('inStudyLine')
                              .replaceAll('{h}', '${r.study!.studyHigh}')
                              .replaceAll('{n}', '${r.study!.studyDays}'),
                          key: const Key('in-study-days'),
                        ),
                        Text(
                          context
                              .tr('inOtherLine')
                              .replaceAll('{h}', '${r.study!.otherHigh}')
                              .replaceAll('{n}', '${r.study!.otherDays}'),
                          key: const Key('in-other-days'),
                        ),
                        const SizedBox(height: 6),
                        Text(context.tr('inNotCause'), style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.5)),
                      ],
                    ],
                  ],
                ],
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _distribution(Map<int, int> counts, String Function(int) label, String prefix, GlowColors c) {
    final max = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: <Widget>[
        for (var i = 5; i >= 1; i--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              key: Key('in-$prefix-$i'),
              children: <Widget>[
                SizedBox(width: 110, child: Text(label(i), style: const TextStyle(fontSize: 13))),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        height: 10,
                        width: max == 0 ? 0 : box.maxWidth * counts[i]! / max,
                        decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${counts[i]}', key: Key('in-$prefix-count-$i'), style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}
