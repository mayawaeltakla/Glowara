/// أذكار الصباح والمساء: نصوص مع عدد التكرار وعدّاد يومي يتجدد كل يوم.
library glowara.feature.worship.adhkar_screen;

import 'package:flutter/material.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';

class Dhikr {
  const Dhikr({required this.text, required this.times, required this.source, this.evening = true, this.morning = true});

  final String text;
  final int times;
  final String source;
  final bool morning;
  final bool evening;
}

/// نصوص مشهورة من القرآن والسنة مع مصدر كل نص.
const List<Dhikr> kDhikrList = <Dhikr>[
  Dhikr(
    text: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَنْ ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
    times: 1,
    source: 'آية الكرسي، سورة البقرة ٢٥٥',
  ),
  Dhikr(
    text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\nقُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
    times: 3,
    source: 'سورة الإخلاص (رواه أبو داود والترمذي)',
  ),
  Dhikr(
    text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\nقُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
    times: 3,
    source: 'سورة الفلق (رواه أبو داود والترمذي)',
  ),
  Dhikr(
    text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\nقُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ',
    times: 3,
    source: 'سورة الناس (رواه أبو داود والترمذي)',
  ),
  Dhikr(
    text: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
    times: 1,
    source: 'رواه مسلم (في المساء: أمسينا وأمسى الملك لله)',
    evening: false,
  ),
  Dhikr(
    text: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
    times: 1,
    source: 'رواه مسلم',
    morning: false,
  ),
  Dhikr(
    text: 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا',
    times: 3,
    source: 'رواه أبو داود والترمذي',
  ),
  Dhikr(
    text: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
    times: 3,
    source: 'رواه أبو داود والترمذي',
  ),
  Dhikr(
    text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    times: 100,
    source: 'رواه مسلم',
  ),
  Dhikr(
    text: 'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
    times: 10,
    source: 'رواه أبو داود والنسائي',
  ),
  Dhikr(
    text: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
    times: 100,
    source: 'متفق عليه',
  ),
];

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key, required this.morning});

  final bool morning;

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late final List<Dhikr> _items = kDhikrList.where((d) => widget.morning ? d.morning : d.evening).toList();
  late List<int> _counts = List<int>.filled(_items.length, 0);
  bool _loaded = false;
  bool _logged = false;

  String get _key =>
      'adhkar_${widget.morning ? 'morning' : 'evening'}_${dateKey(DateTime.now())}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final raw = await AppState.of(context).settings.get<String>(_key);
    if (!mounted) return;
    if (raw != null) {
      final parts = raw.split(',').map((e) => int.tryParse(e) ?? 0).toList();
      if (parts.length == _items.length) setState(() => _counts = parts);
    }
    _logged = _allDone;
  }

  bool get _allDone {
    for (var i = 0; i < _items.length; i++) {
      if (_counts[i] < _items[i].times) return false;
    }
    return true;
  }

  Future<void> _tap(int i) async {
    if (_counts[i] >= _items[i].times) return;
    setState(() => _counts[i]++);
    final state = AppState.of(context);
    await state.settings.set(_key, _counts.join(','));
    if (_allDone && !_logged) {
      _logged = true;
      await state.worship.saveReading(
        ReadingLog(
          id: uniqueId(),
          userId: state.userId,
          itemId: widget.morning ? 'adhkar_morning' : 'adhkar_evening',
          completedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _reset() async {
    setState(() {
      _counts = List<int>.filled(_items.length, 0);
      _logged = false;
    });
    await AppState.of(context).settings.set(_key, _counts.join(','));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final done = _counts.asMap().entries.where((e) => e.value >= _items[e.key].times).length;
    return GlowPage(
      title: widget.morning ? 'أذكار الصباح' : 'أذكار المساء',
      actions: <Widget>[
        IconButton(onPressed: _reset, icon: const Icon(Icons.restart_alt), tooltip: 'إعادة'),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _allDone ? 'أتممتِ أذكار اليوم، تقبّل الله منك' : 'اضغطي على الذكر لعدّ التكرار',
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                      ),
                    ),
                    Text('$done/${_items.length}', style: TextStyle(fontWeight: FontWeight.w700, color: c.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                GlowProgress(value: _items.isEmpty ? 0 : done / _items.length),
                const SizedBox(height: 8),
                Text(
                  'النصوص من القرآن والسنة مع مصدر كل نص. يتجدد العدّاد كل يوم. للتأكد راجعي كتاب حصن المسلم.',
                  style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlowCard(
                onTap: () => _tap(i),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _items[i].text,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 18, height: 2, color: c.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _items[i].source,
                            style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _counts[i] >= _items[i].times ? c.success : c.primaryContainer,
                            borderRadius: BorderRadius.circular(GlowRadius.pill),
                          ),
                          child: Text(
                            _counts[i] >= _items[i].times
                                ? '✓'
                                : '${_counts[i]}/${_items[i].times}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _counts[i] >= _items[i].times ? Colors.white : c.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
