import 'package:sembast/sembast.dart';

/// حالة احتياطية لبيئات غير مدعومة (لا تُستخدم عمليًا على Android/الويب).
Future<Database> openGlowaraDatabase() async {
  throw UnsupportedError('Local database is not available on this platform.');
}
