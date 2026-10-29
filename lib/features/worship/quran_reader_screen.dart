/// قارئ القرآن: نص عثماني من api.alquran.cloud مع تخزين مؤقت محلي
/// وحفظ آخر موضع قراءة. لا يُعدّل النص أو يُعاد ترتيبه.
library glowara.feature.worship.quran_reader_screen;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/worship/quran_service.dart';

class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final QuranService _service = RemoteQuranService();
  bool _didLoad = false;
  bool _loading = true;
  bool _offlineCopy = false;
  String? _error;
  int _surahNumber = 1;
  int _lastReadAyah = 1;
  Surah? _surah;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _restoreAndLoad();
    }
  }

  Future<void> _restoreAndLoad() async {
    final state = AppState.of(context);
    final lastSurah = await state.settings.get<String>('quran_last_surah');
    final parsed = int.tryParse(lastSurah ?? '');
    if (parsed != null && parsed >= 1 && parsed <= 114) {
      _surahNumber = parsed;
    }
    await _load();
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _offlineCopy = false;
    });

    final last = await state.settings.get<String>('quran_last_ayah_$_surahNumber');
    final cachedRaw = await state.settings.get<String>('quran_cache_$_surahNumber');
    Surah? cached;
    if (cachedRaw != null) {
      try {
        cached = Surah.fromApi(jsonDecode(cachedRaw) as Map<String, dynamic>);
      } catch (_) {
        cached = null;
      }
    }

    // عرض النسخة المحلية فورًا عند وجودها، ثم محاولة تحديثها من الشبكة.
    // هذا يحافظ على تجربة الاستخدام عند بطء الإنترنت أو انقطاعه.
    if (cached != null) {
      _surah = cached;
      _lastReadAyah = (int.tryParse(last ?? '') ?? 1)
          .clamp(1, cached.ayahs.isEmpty ? 1 : cached.ayahs.length)
          .toInt();
      if (mounted) {
        setState(() {
          _offlineCopy = true;
          _loading = false;
        });
      }
    }

    final result = await _service.getSurah(_surahNumber);
    if (!mounted) return;

    if (result.ok && result.data != null) {
      try {
        final surah = Surah.fromApi(result.data!);
        _surah = surah;
        await state.settings.set('quran_cache_$_surahNumber', jsonEncode(result.data));
        await state.settings.set('quran_last_surah', _surahNumber.toString());
        if (!mounted) return;
        _lastReadAyah = (int.tryParse(last ?? '') ?? 1)
            .clamp(1, surah.ayahs.isEmpty ? 1 : surah.ayahs.length)
            .toInt();
        setState(() {
          _offlineCopy = false;
          _loading = false;
        });
        return;
      } catch (_) {
        // استجابة غير مكتملة: نكمل إلى النسخة المحلية إن وُجدت.
      }
    }

    if (cached != null) {
      if (mounted) {
        setState(() {
          _offlineCopy = true;
          _loading = false;
        });
      }
      return;
    }

    setState(() {
      _error = result.error ?? context.tr('somethingWentWrong');
      _loading = false;
    });
  }

  Future<void> _changeSurah(int number) async {
    if (number < 1 || number > 114) return;
    setState(() {
      _surahNumber = number;
      _surah = null;
      _lastReadAyah = 1;
      _loading = true;
    });
    await _load();
  }

  Future<void> _pickSurah() async {
    final controller = TextEditingController(text: _surahNumber.toString());
    final l10n = context.l10n;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('chooseSurah')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('surahNumber')),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>[1, 18, 36, 55, 67, 112].map((number) {
                return GlowChoiceChip(
                  label: '$number',
                  selected: _surahNumber == number,
                  onTap: () => Navigator.of(dialogContext).pop(number),
                );
              }).toList(),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 1 && value <= 114) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (selected != null && mounted) {
      await _changeSurah(selected);
    }
  }

  Future<void> _markAyahRead(int ayah) async {
    final surah = _surah;
    if (surah == null) return;
    // لا نرجع بالعلامة إلى الوراء ولا نسجّل قراءات مكررة لنفس الموضع.
    if (ayah <= _lastReadAyah) return;
    setState(() => _lastReadAyah = ayah);
    final state = AppState.of(context);
    await state.settings.set('quran_last_ayah_$_surahNumber', ayah.toString());
    await state.settings.set('quran_last_surah', _surahNumber.toString());
    await state.worship.saveReading(
      ReadingLog(
        id: uniqueId(),
        userId: state.userId,
        itemId: 'quran_surah_$_surahNumber',
        surah: _surahNumber,
        ayahFrom: ayah,
        ayahTo: ayah,
        completedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final surah = _surah;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        title: Text(
          surah == null
              ? l10n.quran
              : ('${surah.name} • ${surah.number}'),
        ),
        backgroundColor: c.scaffold,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : () => _changeSurah(_surahNumber - 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.back,
          ),
          IconButton(
            onPressed: _loading ? null : _pickSurah,
            icon: const Icon(Icons.menu_book),
            tooltip: context.tr('chooseSurah'),
          ),
          IconButton(
            onPressed: _loading ? null : () => _changeSurah(_surahNumber + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.next,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? GlowErrorView(message: _error!, onRetry: _load)
                : surah == null
                    ? GlowErrorView(
                        message: context.tr('somethingWentWrong'),
                        onRetry: _load,
                      )
                    : Column(
                        children: <Widget>[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: c.surfaceAlt,
                            child: Row(
                              children: <Widget>[
                                Icon(Icons.verified_outlined, size: 14, color: c.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _offlineCopy
                                        ? context.tr('quranOffline')
                                        : context.tr('quranSourceNote'),
                                    style: TextStyle(fontSize: 10.5, color: c.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              itemCount: surah.ayahs.length,
                              itemBuilder: (context, index) {
                                final ayah = surah.ayahs[index];
                                final isRead = ayah.numberInSurah <= _lastReadAyah;
                                return _AyahTile(
                                  ayah: ayah,
                                  isRead: isRead,
                                  c: c,
                                  onTap: () => _markAyahRead(ayah.numberInSurah),
                                );
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            color: c.surfaceAlt,
                            child: Row(
                              children: <Widget>[
                                Icon(Icons.bookmark, size: 17, color: c.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${context.tr('lastRead')}: $_lastReadAyah',
                                    style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: surah.ayahs.isEmpty
                                      ? null
                                      : () => _markAyahRead(surah.ayahs.last.numberInSurah),
                                  icon: const Icon(Icons.done_all, size: 16),
                                  label: Text(
                                    context.tr('markAllRead'),
                                    style: const TextStyle(fontSize: 11),
                                  ),
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

class _AyahTile extends StatelessWidget {
  const _AyahTile({
    required this.ayah,
    required this.isRead,
    required this.c,
    required this.onTap,
  });

  final Ayah ayah;
  final bool isRead;
  final GlowColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                ayah.text,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.9,
                  color: c.onSurface,
                  fontFamily: 'Amiri',
                  fontFamilyFallback: const <String>[
                    'Noto Naskh Arabic',
                    'Noto Sans Arabic',
                    'serif',
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${ayah.numberInSurah}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    isRead ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isRead ? c.success : c.onSurfaceVariant,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
