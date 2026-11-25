/// صورة واحدة اختيارية لكل حلم أو لكل ورقة في الزاوية الخاصة.
/// تبقى على الجهاز، وتدخل في النسخة الاحتياطية مع بقية بياناتك (مجموعة `images`).
/// لا تُرسَل إلى أي مكان ولا تغذّي ميزة أخرى.
library glowara.repositories.image;

import 'dart:convert';
import 'dart:typed_data';

import 'package:glowara/core/db/local_database.dart';

const int kPhotoMaxBytes = 700 * 1024;
const List<String> kPhotoOwnerKinds = <String>['dream', 'corner'];

class StoredPhoto {
  const StoredPhoto({required this.id, required this.userId, required this.ownerKind, required this.mime, required this.bytes});

  /// مفتاح السجل = معرّف الحلم أو الورقة.
  final String id;
  final String userId;
  final String ownerKind;
  final String mime;
  final Uint8List bytes;

  static StoredPhoto? tryParse(Map<String, Object?> j) {
    final id = j['id'];
    final userId = j['userId'];
    final kind = j['ownerKind'];
    final mime = j['mime'];
    final data = j['data'];
    if (id is! String || userId is! String || kind is! String || mime is! String || data is! String) return null;
    try {
      return StoredPhoto(id: id, userId: userId, ownerKind: kind, mime: mime, bytes: base64Decode(data));
    } on FormatException {
      return null;
    }
  }
}

/// نوع الصورة من أول بايتات الملف (لا من اسمه). null إن لم تكن صورة مدعومة.
String? sniffImageMime(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length >= 12 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

enum PhotoResult { saved, tooLarge, notImage }

class ImageRepository {
  ImageRepository(this._db);

  final LocalDatabase _db;

  static const String store = 'images';

  Future<StoredPhoto?> get(String userId, String ownerId) async {
    final p = await _db.byId(store, ownerId, (m) => StoredPhoto.tryParse(m));
    return p != null && p.userId == userId ? p : null;
  }

  /// يستبدل صورة المالك إن وُجدت. المالك (حلم/ورقة) يجب أن يكون للمستخدمة؛
  /// يتحقق الاستدعاء من ذلك قبل النداء.
  Future<PhotoResult> set({required String userId, required String ownerKind, required String ownerId, required Uint8List bytes}) async {
    if (!kPhotoOwnerKinds.contains(ownerKind)) throw ArgumentError('owner kind');
    final mime = sniffImageMime(bytes);
    if (mime == null) return PhotoResult.notImage;
    if (bytes.length > kPhotoMaxBytes) return PhotoResult.tooLarge;
    final existing = await _db.byId(store, ownerId, (m) => StoredPhoto.tryParse(m));
    if (existing != null && existing.userId != userId) throw StateError('not yours');
    await _db.put(store, ownerId, <String, dynamic>{
      'id': ownerId,
      'userId': userId,
      'ownerKind': ownerKind,
      'mime': mime,
      'data': base64Encode(bytes),
      'createdAt': DateTime.now().toIso8601String(),
    });
    return PhotoResult.saved;
  }

  Future<void> remove(String userId, String ownerId) async {
    if (await get(userId, ownerId) != null) await _db.delete(store, ownerId);
  }
}
