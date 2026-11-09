import 'package:glowara/core/db/local_database.dart';
import 'package:sembast/sembast_memory.dart';

/// قاعدة بيانات في الذاكرة للاختبارات (معزولة لكل استدعاء).
Future<LocalDatabase> openTestDatabase() async {
  final db = await newDatabaseFactoryMemory().openDatabase('glowara_test.db');
  return LocalDatabase(db);
}
