import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/library_models.dart';
import 'package:glowara/core/repositories/library_repository.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';

void main() {
  group('models', () {
    test('Book round-trips and tolerates bad data', () {
      final b = Book(
        id: 'b1',
        userId: _a,
        title: 't',
        status: 'reading',
        totalPages: 300,
        currentPage: 20,
        notes: <BookNote>[BookNote(id: 'n1', kind: 'quote', text: 'q', page: 5, createdAt: DateTime(2026, 11, 1))],
        startedAt: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      );
      final back = Book.fromJson(b.toJson());
      expect(back.totalPages, 300);
      expect(back.notes.single.page, 5);
      expect(back.startedAt, isNotNull);
      final json = b.toJson()
        ..['status'] = 'weird'
        ..['totalPages'] = -3
        ..['currentPage'] = 'x'
        ..['notes'] = <Object?>[1, <String, Object?>{'id': 'n', 'text': ' '}, <String, Object?>{'id': 'n2', 'kind': 'zzz', 'text': 'ok', 'page': 0}];
      final t = Book.fromJson(json);
      expect(t.status, 'want');
      expect(t.totalPages, isNull);
      expect(t.currentPage, 0);
      expect(t.notes.single.kind, 'note');
      expect(t.notes.single.page, isNull);
    });
  });

  group('repository', () {
    late LocalDatabase db;
    late LibraryRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = LibraryRepository(db);
    });

    test('title is required; texts are trimmed and capped', () async {
      expect(() => repo.save(userId: _a, title: '  '), throwsStateError);
      final b = await repo.save(userId: _a, title: '  ${'ك' * 200}  ', author: ' مؤلف ', category: 'ر' * 99);
      expect(b.title.length, kBookTitleMax);
      expect(b.author, 'مؤلف');
      expect(b.category.length, kBookCategoryMax);
    });

    test('current page is clamped to total pages; invalid totals are dropped', () async {
      final b = await repo.save(userId: _a, title: 't', totalPages: 100, currentPage: 500);
      expect(b.currentPage, 100);
      final c = await repo.save(userId: _a, title: 't', totalPages: 0, currentPage: -5);
      expect(c.totalPages, isNull);
      expect(c.currentPage, 0);
    });

    test('status changes set and clear dates', () async {
      final t0 = DateTime(2026, 11, 1);
      final t1 = DateTime(2026, 11, 5);
      final b = await repo.save(userId: _a, title: 't', now: t0);
      expect(b.startedAt, isNull);
      final r = await repo.save(userId: _a, id: b.id, title: 't', status: 'reading', now: t1);
      expect(r.startedAt, t1);
      final f = await repo.save(userId: _a, id: b.id, title: 't', status: 'finished', now: DateTime(2026, 11, 9));
      expect(f.startedAt, t1);
      expect(f.finishedAt, DateTime(2026, 11, 9));
      final back = await repo.save(userId: _a, id: b.id, title: 't', status: 'reading');
      expect(back.finishedAt, isNull);
      expect(back.startedAt, t1);
      expect(back.createdAt, t0);
    });

    test('notes: add, cap, bad input, delete; other accounts cannot touch them', () async {
      final b = await repo.save(userId: _a, title: 't');
      final n = await repo.addNote(userId: _a, bookId: b.id, kind: 'quote', text: '  اقتباس  ', page: 12);
      expect(n.notes.single.text, 'اقتباس');
      expect(n.notes.single.page, 12);
      expect(() => repo.addNote(userId: _a, bookId: b.id, kind: 'note', text: ' '), throwsStateError);
      expect(() => repo.addNote(userId: _b, bookId: b.id, kind: 'note', text: 'x'), throwsStateError);
      expect(await repo.byId(_b, b.id), isNull);
      for (var i = 1; i < kBookMaxNotes; i++) {
        await repo.addNote(userId: _a, bookId: b.id, kind: 'note', text: 'n$i');
      }
      expect(() => repo.addNote(userId: _a, bookId: b.id, kind: 'note', text: 'more'), throwsStateError);
      final after = await repo.deleteNote(userId: _a, bookId: b.id, noteId: n.notes.single.id);
      expect(after.notes.length, kBookMaxNotes - 1);
    });

    test('delete removes the book with its notes; only the owner can delete', () async {
      final b = await repo.save(userId: _a, title: 't');
      await repo.addNote(userId: _a, bookId: b.id, kind: 'note', text: 'x');
      await repo.delete(_b, b.id);
      expect(await repo.all(_a), hasLength(1));
      await repo.delete(_a, b.id);
      expect(await repo.all(_a), isEmpty);
      expect(await db.count('books'), 0);
    });
  });

  group('export, import and delete account', () {
    test('account export, restore, re-key and account deletion', () async {
      final db = await openTestDatabase();
      final repo = LibraryRepository(db);
      final a = await repo.save(userId: _a, title: 'كتابي');
      await repo.addNote(userId: _a, bookId: a.id, kind: 'summary', text: 'ملخص');
      await repo.save(userId: _b, title: 'كتابها');

      final export = await db.exportAll(onlyUserId: _a);
      expect((export['books'] as Map).keys, <String>[a.id]);

      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _a);
      final restored = (await LibraryRepository(fresh).all(_a)).single;
      expect(restored.notes.single.text, 'ملخص');

      final other = await openTestDatabase();
      await other.importAll(export, targetUserId: _b, allowDifferentSource: true);
      expect((await LibraryRepository(other).all(_b)).single.userId, _b);

      await db.deleteUserData(_a);
      expect(await repo.all(_a), isEmpty);
      expect(await repo.all(_b), hasLength(1));
    });
  });
}
