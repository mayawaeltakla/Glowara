/// مواقيت الصلاة واتجاه القبلة: تُحسب على الجهاز دون إنترنت أو إذن موقع.
///
/// المستخدمة تختار مدينتها من قائمة، فلا يُجمع موقعها الفعلي. الحساب فلكي
/// وتختلف طرقه قليلًا بين الجهات؛ للاحتياط يُنصح بمطابقته مع مسجد الحي.
library glowara.services.prayer;

import 'package:adhan/adhan.dart';

class PrayerCity {
  const PrayerCity(this.id, this.nameAr, this.nameEn, this.lat, this.lon);

  final String id;
  final String nameAr;
  final String nameEn;
  final double lat;
  final double lon;
}

const List<PrayerCity> kPrayerCities = <PrayerCity>[
  PrayerCity('damascus', 'دمشق', 'Damascus', 33.5138, 36.2765),
  PrayerCity('aleppo', 'حلب', 'Aleppo', 36.2021, 37.1343),
  PrayerCity('homs', 'حمص', 'Homs', 34.7324, 36.7137),
  PrayerCity('hama', 'حماة', 'Hama', 35.1318, 36.7578),
  PrayerCity('latakia', 'اللاذقية', 'Latakia', 35.5317, 35.7915),
  PrayerCity('tartus', 'طرطوس', 'Tartus', 34.8959, 35.8867),
  PrayerCity('daraa', 'درعا', 'Daraa', 32.6189, 36.1021),
  PrayerCity('deir', 'دير الزور', 'Deir ez-Zor', 35.3359, 40.1408),
  PrayerCity('raqqa', 'الرقة', 'Raqqa', 35.9528, 39.0079),
  PrayerCity('hasakah', 'الحسكة', 'Al-Hasakah', 36.5024, 40.7477),
  PrayerCity('idlib', 'إدلب', 'Idlib', 35.9306, 36.6339),
  PrayerCity('suwayda', 'السويداء', 'As-Suwayda', 32.7090, 36.5663),
  PrayerCity('beirut', 'بيروت', 'Beirut', 33.8938, 35.5018),
  PrayerCity('amman', 'عمّان', 'Amman', 31.9454, 35.9284),
  PrayerCity('jerusalem', 'القدس', 'Jerusalem', 31.7683, 35.2137),
  PrayerCity('gaza', 'غزة', 'Gaza', 31.5017, 34.4668),
  PrayerCity('baghdad', 'بغداد', 'Baghdad', 33.3152, 44.3661),
  PrayerCity('istanbul', 'إسطنبول', 'Istanbul', 41.0082, 28.9784),
  PrayerCity('cairo', 'القاهرة', 'Cairo', 30.0444, 31.2357),
  PrayerCity('riyadh', 'الرياض', 'Riyadh', 24.7136, 46.6753),
  PrayerCity('jeddah', 'جدة', 'Jeddah', 21.4858, 39.1925),
  PrayerCity('mecca', 'مكة المكرمة', 'Mecca', 21.3891, 39.8579),
  PrayerCity('medina', 'المدينة المنورة', 'Medina', 24.5247, 39.5692),
  PrayerCity('dubai', 'دبي', 'Dubai', 25.2048, 55.2708),
  PrayerCity('doha', 'الدوحة', 'Doha', 25.2854, 51.5310),
  PrayerCity('kuwait', 'الكويت', 'Kuwait City', 29.3759, 47.9774),
  PrayerCity('muscat', 'مسقط', 'Muscat', 23.5880, 58.3829),
  PrayerCity('sanaa', 'صنعاء', 'Sanaa', 15.3694, 44.1910),
  PrayerCity('khartoum', 'الخرطوم', 'Khartoum', 15.5007, 32.5599),
  PrayerCity('tripoli', 'طرابلس', 'Tripoli', 32.8872, 13.1913),
  PrayerCity('tunis', 'تونس', 'Tunis', 36.8065, 10.1815),
  PrayerCity('algiers', 'الجزائر', 'Algiers', 36.7538, 3.0588),
  PrayerCity('rabat', 'الرباط', 'Rabat', 34.0209, -6.8416),
  PrayerCity('berlin', 'برلين', 'Berlin', 52.5200, 13.4050),
  PrayerCity('london', 'لندن', 'London', 51.5074, -0.1278),
];

/// طرق الحساب المتاحة (معرّف → اسم).
const Map<String, String> kPrayerMethods = <String, String>{
  'egyptian': 'الهيئة المصرية العامة للمساحة',
  'mwl': 'رابطة العالم الإسلامي',
  'umm_al_qura': 'أم القرى (مكة)',
  'turkey': 'ديانت التركية',
  'dubai': 'دبي',
  'qatar': 'قطر',
  'kuwait': 'الكويت',
};

const String kDefaultPrayerCity = 'damascus';
const String kDefaultPrayerMethod = 'egyptian';

PrayerCity prayerCityById(String? id) =>
    kPrayerCities.firstWhere((c) => c.id == id, orElse: () => kPrayerCities.first);

CalculationParameters _params(String method, bool hanafi) {
  final CalculationParameters p;
  switch (method) {
    case 'mwl':
      p = CalculationMethod.muslim_world_league.getParameters();
    case 'umm_al_qura':
      p = CalculationMethod.umm_al_qura.getParameters();
    case 'turkey':
      p = CalculationMethod.turkey.getParameters();
    case 'dubai':
      p = CalculationMethod.dubai.getParameters();
    case 'qatar':
      p = CalculationMethod.qatar.getParameters();
    case 'kuwait':
      p = CalculationMethod.kuwait.getParameters();
    default:
      p = CalculationMethod.egyptian.getParameters();
  }
  p.madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
  return p;
}

/// مواقيت يوم واحد بالتوقيت المحلي للجهاز.
class PrayerDay {
  const PrayerDay({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  /// (المعرّف، الوقت) بالترتيب.
  List<(String, DateTime)> get entries => <(String, DateTime)>[
        ('fajr', fajr),
        ('sunrise', sunrise),
        ('dhuhr', dhuhr),
        ('asr', asr),
        ('maghrib', maghrib),
        ('isha', isha),
      ];
}

PrayerDay computePrayerDay({
  required PrayerCity city,
  required String method,
  required bool hanafi,
  required DateTime date,
}) {
  final coords = Coordinates(city.lat, city.lon);
  final times = PrayerTimes(coords, DateComponents(date.year, date.month, date.day), _params(method, hanafi));
  return PrayerDay(
    fajr: times.fajr.toLocal(),
    sunrise: times.sunrise.toLocal(),
    dhuhr: times.dhuhr.toLocal(),
    asr: times.asr.toLocal(),
    maghrib: times.maghrib.toLocal(),
    isha: times.isha.toLocal(),
  );
}

/// اتجاه القبلة بالدرجات مع عقارب الساعة من الشمال الحقيقي.
double qiblaDegrees(PrayerCity city) => Qibla(Coordinates(city.lat, city.lon)).direction;
