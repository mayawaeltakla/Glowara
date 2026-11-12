import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/services/prayer_service.dart';

void main() {
  test('prayer times are ordered through the day', () {
    final day = computePrayerDay(
      city: prayerCityById('damascus'),
      method: 'egyptian',
      hanafi: false,
      date: DateTime(2026, 11, 12),
    );
    final t = day.entries.map((e) => e.$2).toList();
    for (var i = 1; i < t.length; i++) {
      expect(t[i].isAfter(t[i - 1]), isTrue, reason: '${day.entries[i].$1} after ${day.entries[i - 1].$1}');
    }
  });

  test('Hanafi asr is later than Shafi asr', () {
    final shafi = computePrayerDay(
        city: prayerCityById('damascus'), method: 'egyptian', hanafi: false, date: DateTime(2026, 11, 12));
    final hanafi = computePrayerDay(
        city: prayerCityById('damascus'), method: 'egyptian', hanafi: true, date: DateTime(2026, 11, 12));
    expect(hanafi.asr.isAfter(shafi.asr), isTrue);
  });

  test('qibla from Damascus points south-east, from Mecca-side cities differ', () {
    final damascus = qiblaDegrees(prayerCityById('damascus'));
    expect(damascus, inInclusiveRange(150, 175));
    final london = qiblaDegrees(prayerCityById('london'));
    expect(london, inInclusiveRange(110, 130));
  });

  test('unknown city id falls back to the first city', () {
    expect(prayerCityById('nowhere').id, kPrayerCities.first.id);
  });
}
