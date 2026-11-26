import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/repositories/corner_repository.dart';
import 'package:glowara/core/repositories/dream_repository.dart';
import 'package:glowara/core/repositories/image_repository.dart';

import 'support/test_db.dart';

final Uint8List kPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late LocalDatabase db;
  late ImageRepository images;

  setUp(() async {
    db = await openTestDatabase();
    images = ImageRepository(db);
  });

  test('file type comes from the bytes, not the name', () {
    expect(sniffImageMime(kPng), 'image/png');
    expect(sniffImageMime(Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0])), 'image/jpeg');
    expect(sniffImageMime(Uint8List.fromList(utf8.encode('RIFF....WEBPVP8 '))), 'image/webp');
    expect(sniffImageMime(Uint8List.fromList(utf8.encode('hello world, not an image'))), isNull);
    expect(sniffImageMime(Uint8List(0)), isNull);
  });

  test('saves, reads back and replaces a photo for its owner only', () async {
    expect(await images.set(userId: 'u1', ownerKind: 'dream', ownerId: 'd1', bytes: kPng), PhotoResult.saved);
    final p = await images.get('u1', 'd1');
    expect(p!.bytes, kPng);
    expect(p.mime, 'image/png');
    expect(await images.get('u2', 'd1'), isNull, reason: 'another account never sees it');
    expect(() => images.set(userId: 'u2', ownerKind: 'dream', ownerId: 'd1', bytes: kPng), throwsStateError);
    expect(await db.count('images'), 1);
  });

  test('rejects non-images and oversized files without storing anything', () async {
    expect(await images.set(userId: 'u1', ownerKind: 'dream', ownerId: 'd1', bytes: Uint8List.fromList(utf8.encode('x' * 50))), PhotoResult.notImage);
    final big = Uint8List(kPhotoMaxBytes + 1)..setRange(0, kPng.length, kPng);
    expect(await images.set(userId: 'u1', ownerKind: 'corner', ownerId: 'c1', bytes: big), PhotoResult.tooLarge);
    expect(await db.count('images'), 0);
    expect(() => images.set(userId: 'u1', ownerKind: 'task', ownerId: 'x', bytes: kPng), throwsArgumentError);
  });

  test('deleting a dream or a corner entry deletes its photo too', () async {
    final dream = await DreamRepository(db).save(userId: 'u1', title: 'حلم');
    await images.set(userId: 'u1', ownerKind: 'dream', ownerId: dream.id, bytes: kPng);
    await DreamRepository(db).delete('u1', dream.id);
    expect(await images.get('u1', dream.id), isNull);

    final entry = await CornerRepository(db).save(userId: 'u1', kind: 'memory', title: 'ذكرى', text: 'نص');
    await images.set(userId: 'u1', ownerKind: 'corner', ownerId: entry.id, bytes: kPng);
    await CornerRepository(db).delete('u1', entry.id);
    expect(await images.get('u1', entry.id), isNull);
    expect(await db.count('images'), 0);
  });

  test('a photo travels with the account backup and not with another account', () async {
    await images.set(userId: 'u1', ownerKind: 'dream', ownerId: 'd1', bytes: kPng);
    await images.set(userId: 'u2', ownerKind: 'dream', ownerId: 'd2', bytes: kPng);
    final mine = jsonEncode(await db.exportAll(onlyUserId: 'u1'));
    expect(mine.contains('"d1"'), isTrue);
    expect(mine.contains('"d2"'), isFalse);
  });
}
