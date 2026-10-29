/// العبادات: متابعة الصلوات، فتح المصحف، عدّ التسبيح/الاستغفار،
/// وتوضيح صريح للأذكار غير المرتبطة بمصدر بعد.
library glowara.feature.worship.worship_screen;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:go_router/go_router.dart';

class WorshipScreen extends StatefulWidget {
  const WorshipScreen({super.key});

  @override
  State<WorshipScreen> createState() => _WorshipScreenState();
}

class _WorshipScreenState extends State<WorshipScreen> {
  bool _didLoad = false;
  bool _loading = true;
  final Map<String, ReadingLog> _prayerLogs = <String, ReadingLog>{};

  static const List<WorshipItem> _prayers = <WorshipItem>[
    WorshipItem(id: 'prayer_fajr', type: 'prayer', reference: 'fajr', titleAr: 'صلاة الفجر', titleEn: 'Fajr'),
    WorshipItem(id: 'prayer_dhuhr', type: 'prayer', reference: 'dhuhr', titleAr: 'صلاة الظهر', titleEn: 'Dhuhr'),
    WorshipItem(id: 'prayer_asr', type: 'prayer', reference: 'asr', titleAr: 'صلاة العصر', titleEn: 'Asr'),
    WorshipItem(id: 'prayer_maghrib', type: 'prayer', reference: 'maghrib', titleAr: 'صلاة المغرب', titleEn: 'Maghrib'),
    WorshipItem(id: 'prayer_isha', type: 'prayer', reference: 'isha', titleAr: 'صلاة العشاء', titleEn: 'Isha'),
  ];

  static const List<WorshipItem> _adhkar = <WorshipItem>[
    WorshipItem(id: 'adhkar_morning', type: 'adkar', reference: 'morning', titleAr: 'أذكار الصباح', titleEn: 'Morning adhkar'),
    WorshipItem(id: 'adhkar_evening', type: 'adkar', reference: 'evening', titleAr: 'أذكار المساء', titleEn: 'Evening adhkar'),
    WorshipItem(id: 'dua', type: 'dua', reference: 'dua', titleAr: 'الدعاء', titleEn: 'Dua'),
  ];

  static const List<WorshipItem> _counters = <WorshipItem>[
    WorshipItem(id: 'tasbih', type: 'tasbih', reference: 'tasbih', titleAr: 'التسبيح', titleEn: 'Tasbih'),
    WorshipItem(id: 'istighfar', type: 'istighfar', reference: 'istighfar', titleAr: 'الاستغفار', titleEn: 'Istighfar'),
  ];

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
    final logs = await state.worship.readings(userId: state.userId);
    if (!mounted) return;
    final today = logs.where((l) => isSameDay(l.completedAt, DateTime.now())).where(
          (l) => l.itemId.startsWith('prayer_'),
        );
    final map = <String, ReadingLog>{};
    for (final log in today) {
      map.putIfAbsent(log.itemId, () => log);
    }
    setState(() {
      _prayerLogs
        ..clear()
        ..addAll(map);
      _loading = false;
    });
  }

  Future<void> _togglePrayer(WorshipItem item) async {
    final state = AppState.of(context);
    final existing = _prayerLogs[item.id];
    final now = DateTime.now();
    if (existing != null) {
      await state.worship.deleteReading(existing.id);
    } else {
      await state.worship.saveReading(
        ReadingLog(
          // معرّف ثابت لليوم يمنع تكرار سجل الصلاة عند النقر السريع.
          id: 'worship_${item.id}_${dateKey(now)}',
          userId: state.userId,
          itemId: item.id,
          completedAt: now,
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? context.tr('prayerCompleted')
              : context.tr('prayerUnmarked'),
        ),
      ),
    );
    _load();
  }

  Future<void> _openCounter(WorshipItem item) async {
    final state = AppState.of(context);
    final initial = await state.settings.get<int>('tasbih_count_${item.id}') ?? 0;
    if (!mounted) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final count = await showDialog<int>(
      context: context,
      builder: (_) => _TasbihDialog(
        title: isArabic ? item.titleAr : item.titleEn,
        initial: initial,
      ),
    );
    if (count == null || !mounted) return;
    await state.settings.set('tasbih_count_${item.id}', count);
    await state.worship.saveReading(
      ReadingLog(
        id: uniqueId(),
        userId: state.userId,
        itemId: item.id,
        completedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('tasbihSaved'))),
    );
  }

  Future<void> _showSourcePending(WorshipItem item) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? item.titleAr : item.titleEn),
        content: Text(context.tr('adhkarUnavailableSub')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final completedPrayers = _prayers.where((p) => _prayerLogs.containsKey(p.id)).length;

    return GlowPage(
      title: l10n.worship,
      actions: <Widget>[
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: <Widget>[
                GlowCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.mosque, color: c.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('prayerTracking'),
                            style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                          ),
                          const Spacer(),
                          Text(
                            '$completedPrayers/${_prayers.length}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: c.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GlowProgress(value: completedPrayers / _prayers.length),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('worshipSub'),
                        style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ..._prayers.map((item) {
                  final done = _prayerLogs.containsKey(item.id);
                  return GlowCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: ListTile(
                      leading: Icon(
                        done ? Icons.check_circle : Icons.mosque_outlined,
                        color: done ? c.success : c.primary,
                      ),
                      title: Text(
                        isArabic ? item.titleAr : item.titleEn,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: done ? c.onSurfaceVariant : c.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        done ? context.tr('completedToday') : context.tr('markPrayer'),
                        style: TextStyle(fontSize: 10.5, color: c.onSurfaceVariant),
                      ),
                      trailing: Checkbox(
                        value: done,
                        onChanged: (_) => _togglePrayer(item),
                      ),
                      onTap: () => _togglePrayer(item),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                GlowSectionTitle(
                  title: context.tr('quranReading'),
                  icon: Icons.menu_book,
                ),
                GlowCard(
                  onTap: () async {
                    await context.push('/quran');
                    if (mounted) _load();
                  },
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: c.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.menu_book, color: c.primary, size: 21),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.quran,
                              style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                            ),
                            Text(
                              context.tr('quranOpenSub'),
                              style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                            ),
                            Text(
                              'api.alquran.cloud',
                              style: TextStyle(fontSize: 9.5, color: c.primary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GlowSectionTitle(
                  title: l10n.adhkar,
                  icon: Icons.rss_feed,
                ),
                ..._adhkar.map((item) {
                  return GlowCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: ListTile(
                      leading: Icon(Icons.info_outline, color: c.gold),
                      title: Text(isArabic ? item.titleAr : item.titleEn),
                      subtitle: Text(
                        context.tr('sourcePending'),
                        style: TextStyle(fontSize: 10.5, color: c.onSurfaceVariant),
                      ),
                      trailing: Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                      onTap: () => _showSourcePending(item),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                GlowSectionTitle(
                  title: l10n.tasbih,
                  icon: Icons.favorite_border,
                ),
                ..._counters.map((item) {
                  return GlowCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: ListTile(
                      leading: Icon(Icons.add_circle_outline, color: c.primary),
                      title: Text(isArabic ? item.titleAr : item.titleEn),
                      subtitle: Text(
                        context.tr('tasbihHint'),
                        style: TextStyle(fontSize: 10.5, color: c.onSurfaceVariant),
                      ),
                      trailing: Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                      onTap: () => _openCounter(item),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _TasbihDialog extends StatefulWidget {
  const _TasbihDialog({required this.title, required this.initial});

  final String title;
  final int initial;

  @override
  State<_TasbihDialog> createState() => _TasbihDialogState();
}

class _TasbihDialogState extends State<_TasbihDialog> {
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$_count',
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w800,
              color: c.primary,
            ),
          ),
          Text(
            context.tr('countLabel'),
            style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => setState(() => _count = 0),
                child: Text(l10n.reset),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => setState(() => _count++),
                child: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('tasbihHint'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: c.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_count),
          child: Text(context.tr('saveCount')),
        ),
      ],
    );
  }
}
