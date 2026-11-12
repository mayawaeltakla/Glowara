/// مواقيت الصلاة واتجاه القبلة والتاريخ الهجري (حساب محلي دون إنترنت).
library glowara.feature.worship.prayer_times_screen;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:glowara/core/services/prayer_service.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  bool _loaded = false;
  String _cityId = kDefaultPrayerCity;
  String _method = kDefaultPrayerMethod;
  bool _hanafi = false;

  static const Map<String, String> _names = <String, String>{
    'fajr': 'الفجر',
    'sunrise': 'الشروق',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final s = AppState.of(context).settings;
    final city = await s.get<String>('prayer_city');
    final method = await s.get<String>('prayer_method');
    final madhab = await s.get<String>('prayer_madhab');
    if (!mounted) return;
    setState(() {
      _cityId = city ?? kDefaultPrayerCity;
      _method = kPrayerMethods.containsKey(method) ? method! : kDefaultPrayerMethod;
      _hanafi = madhab == 'hanafi';
    });
  }

  Future<void> _save() async {
    final s = AppState.of(context).settings;
    await s.set('prayer_city', _cityId);
    await s.set('prayer_method', _method);
    await s.set('prayer_madhab', _hanafi ? 'hanafi' : 'shafi');
  }

  String _hijriText() {
    try {
      HijriCalendar.setLocal('ar');
      final h = HijriCalendar.now();
      return '${h.hDay} ${h.longMonthName} ${h.hYear} هـ';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final city = prayerCityById(_cityId);
    final now = DateTime.now();
    PrayerDay? day;
    String? error;
    try {
      day = computePrayerDay(city: city, method: _method, hanafi: _hanafi, date: now);
    } catch (e) {
      error = 'تعذّر حساب المواقيت.';
    }

    // الصلاة القادمة (من الفجر إلى العشاء دون الشروق).
    String? nextId;
    Duration? untilNext;
    if (day != null) {
      for (final (id, t) in day.entries) {
        if (id == 'sunrise') continue;
        if (t.isAfter(now)) {
          nextId = id;
          untilNext = t.difference(now);
          break;
        }
      }
    }
    final fmt = DateFormat('h:mm a', 'ar');
    final hijri = _hijriText();

    return GlowPage(
      title: 'مواقيت الصلاة',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          GlowCard(
            gradient: c.heroGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  DateFormat('EEEE d MMMM yyyy', 'ar').format(now),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                if (hijri.isNotEmpty)
                  Text(hijri, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                if (nextId != null && untilNext != null)
                  Text(
                    'الصلاة القادمة: ${_names[nextId]} بعد '
                    '${untilNext.inHours} س ${untilNext.inMinutes % 60} د',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  )
                else
                  const Text(
                    'انتهت صلوات اليوم. الفجر غدًا بإذن الله.',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (error != null)
            GlowCard(child: Text(error))
          else if (day != null)
            ...day.entries.map((e) {
              final isNext = e.$1 == nextId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlowCard(
                  color: isNext ? c.primaryContainer : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _names[e.$1]!,
                          style: TextStyle(
                            fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                            color: c.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        fmt.format(e.$2),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isNext ? c.primary : c.onSurface,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 4),
          GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('المدينة وطريقة الحساب',
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _cityId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المدينة'),
                  items: kPrayerCities
                      .map((x) => DropdownMenuItem<String>(value: x.id, child: Text(x.nameAr)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _cityId = v);
                    _save();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'طريقة الحساب'),
                  items: kPrayerMethods.entries
                      .map((x) => DropdownMenuItem<String>(value: x.key, child: Text(x.value)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _method = v);
                    _save();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _hanafi,
                  onChanged: (v) {
                    setState(() => _hanafi = v);
                    _save();
                  },
                  title: const Text('العصر على المذهب الحنفي'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlowCard(
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CustomPaint(painter: _QiblaPainter(qiblaDegrees(city), c.primary, c.border, c.gold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('اتجاه القبلة',
                          style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                      const SizedBox(height: 4),
                      Text(
                        '${qiblaDegrees(city).toStringAsFixed(0)}° من الشمال مع عقارب الساعة',
                        style: TextStyle(color: c.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'وجّهي أعلى الهاتف نحو الشمال ثم دوري بهذه الزاوية. للتأكد استعملي بوصلة هاتفك.',
                        style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'تُحسب المواقيت على جهازك بلا إنترنت حسب المدينة المختارة، وقد تختلف دقائق قليلة عن مسجد حيّك أو التقويم المعتمد، فاعتمدي ما اعتدتِ عليه. التاريخ الهجري قد يختلف يومًا حسب رؤية الهلال.',
            style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// قرص صغير: الشمال إلى الأعلى وسهم يشير إلى زاوية القبلة.
class _QiblaPainter extends CustomPainter {
  _QiblaPainter(this.degrees, this.primary, this.border, this.gold);

  final double degrees;
  final Color primary;
  final Color border;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = border,
    );
    // علامة الشمال.
    canvas.drawCircle(center.translate(0, -r), 4, Paint()..color = gold);
    final angle = degrees * math.pi / 180;
    final tip = center + Offset(math.sin(angle), -math.cos(angle)) * (r - 6);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = primary
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(tip, 5, Paint()..color = primary);
    canvas.drawCircle(center, 4, Paint()..color = primary);
  }

  @override
  bool shouldRepaint(covariant _QiblaPainter old) => old.degrees != degrees || old.primary != primary;
}
