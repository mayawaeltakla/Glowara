import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// فتح قاعدة البيانات على Android (ملف داخل مجلد التطبيق).
Future<Database> openGlowaraDatabase() async {
  final base = await getApplicationDocumentsDirectory();
  final folder = Directory(p.join(base.path, 'glowara'));
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  return databaseFactoryIo.openDatabase(p.join(folder.path, 'glowara.db'));
}
