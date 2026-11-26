/// مستودع «مكتبتي». يكتب سجلات `books` وحدها (الملاحظات داخل سجل الكتاب).
/// لا يقرأ ميزة أخرى ولا يغذّي الإنجازات أو الملخصات.
library glowara.repositories.library;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/library_models.dart';

class LibraryRepository {
  LibraryRepository(this._db);

  final LocalDatabase _db;

  static const String _store = 'books';

  Future<List<Book>> all(String userId) async {
    final list = await _db.list(_store, Book.fromJson, filter: Filter.equals('userId', userId));
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<Book?> byId(String userId, String id) async {
    final b = await _db.byId(_store, id, Book.fromJson);
    return b != null && b.userId == userId ? b : null;
  }

  String _cut(String s, int max) {
    final t = s.trim();
    return t.length > max ? t.substring(0, max) : t;
  }

  /// يحفظ كتابًا (جديدًا إن كان [id] فارغًا). العنوان مطلوب. رقم الصفحة الحالية
  /// يُقصّ على إجمالي الصفحات إن عُرف. الانتقال إلى «أقرأ» يضع تاريخ البدء مرة،
  /// وإلى «أنهيت» يضع تاريخ الإنهاء، والرجوع من «أنهيت» يمسحه.
  Future<Book> save({
    required String userId,
    String? id,
    required String title,
    String author = '',
    String category = '',
    String status = 'want',
    int? totalPages,
    int currentPage = 0,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final cleanTitle = _cut(title, kBookTitleMax);
    if (cleanTitle.isEmpty) throw StateError('empty title');
    final st = kBookStatuses.contains(status) ? status : 'want';
    final total = totalPages != null && totalPages >= 1 && totalPages <= kBookMaxPages ? totalPages : null;
    var cur = currentPage < 0 ? 0 : currentPage;
    if (cur > kBookMaxPages) cur = kBookMaxPages;
    if (total != null && cur > total) cur = total;
    final existing = id == null ? null : await byId(userId, id);
    DateTime? started = existing?.startedAt;
    DateTime? finished = existing?.finishedAt;
    if (st != 'want') started ??= stamp;
    if (st == 'finished') {
      finished ??= stamp;
    } else {
      finished = null;
    }
    final book = Book(
      id: existing?.id ?? uniqueId(),
      userId: userId,
      title: cleanTitle,
      author: _cut(author, kBookAuthorMax),
      category: _cut(category, kBookCategoryMax),
      status: st,
      totalPages: total,
      currentPage: cur,
      notes: existing?.notes ?? const <BookNote>[],
      startedAt: started,
      finishedAt: finished,
      createdAt: existing?.createdAt ?? stamp,
      updatedAt: stamp,
    );
    await _db.put(_store, book.id, book.toJson());
    return book;
  }

  Future<void> delete(String userId, String id) async {
    if (await byId(userId, id) != null) await _db.delete(_store, id);
  }

  /// يضيف ملاحظة/اقتباسًا/ملخصًا. يرمي [StateError] إن كان النص فارغًا أو بلغ الحدّ.
  Future<Book> addNote({
    required String userId,
    required String bookId,
    required String kind,
    required String text,
    int? page,
    DateTime? now,
  }) async {
    final book = await byId(userId, bookId);
    if (book == null) throw StateError('no such book');
    final clean = _cut(text, kBookNoteMax);
    if (clean.isEmpty) throw StateError('empty note');
    if (book.notes.length >= kBookMaxNotes) throw StateError('too many notes');
    final stamp = now ?? DateTime.now();
    final note = BookNote(
      id: uniqueId(),
      kind: kNoteKinds.contains(kind) ? kind : 'note',
      text: clean,
      page: page != null && page >= 1 && page <= kBookMaxPages ? page : null,
      createdAt: stamp,
    );
    final out = book.copyWith(notes: <BookNote>[...book.notes, note], updatedAt: stamp);
    await _db.put(_store, out.id, out.toJson());
    return out;
  }

  Future<Book> deleteNote({required String userId, required String bookId, required String noteId}) async {
    final book = await byId(userId, bookId);
    if (book == null) throw StateError('no such book');
    final out = book.copyWith(notes: book.notes.where((n) => n.id != noteId).toList(), updatedAt: DateTime.now());
    await _db.put(_store, out.id, out.toJson());
    return out;
  }
}
