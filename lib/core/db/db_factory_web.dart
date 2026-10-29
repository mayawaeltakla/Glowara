import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

/// فتح قاعدة البيانات على الويب (IndexedDB).
Future<Database> openGlowaraDatabase() async {
  return databaseFactoryWeb.openDatabase('glowara.db');
}
