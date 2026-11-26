/// نماذج «مكتبتي»: كتب تقرئينها أو تريدين قراءتها، مع صفحة وصلتِ إليها وملاحظات
/// واقتباسات وملخصات تكتبينها. بلا نسب ولا أهداف قراءة ولا مقارنة ولا سلاسل.
library glowara.models.library;

const List<String> kBookStatuses = <String>['want', 'reading', 'finished'];
const List<String> kNoteKinds = <String>['note', 'quote', 'summary'];

const int kBookTitleMax = 100;
const int kBookAuthorMax = 60;
const int kBookCategoryMax = 30;
const int kBookNoteMax = 1000;
const int kBookMaxNotes = 100;
const int kBookMaxPages = 20000;

class BookNote {
  const BookNote({required this.id, required this.kind, required this.text, this.page, required this.createdAt});

  final String id;

  /// note | quote | summary
  final String kind;
  final String text;
  final int? page;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind,
        'text': text,
        'page': page,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static BookNote? tryParse(Object? v) {
    if (v is! Map) return null;
    final id = v['id'];
    final text = v['text'];
    if (id is! String || id.isEmpty || text is! String || text.trim().isEmpty) return null;
    final kind = v['kind'];
    final page = v['page'];
    return BookNote(
      id: id,
      kind: kind is String && kNoteKinds.contains(kind) ? kind : 'note',
      text: text,
      page: page is int && page >= 1 && page <= kBookMaxPages ? page : null,
      createdAt: (v['createdAt'] is String ? DateTime.tryParse(v['createdAt'] as String)?.toLocal() : null) ??
          DateTime.now(),
    );
  }
}

class Book {
  const Book({
    required this.id,
    required this.userId,
    required this.title,
    this.author = '',
    this.category = '',
    this.status = 'want',
    this.totalPages,
    this.currentPage = 0,
    this.notes = const <BookNote>[],
    this.startedAt,
    this.finishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String author;

  /// تصنيف حرّ تكتبه المستخدمة.
  final String category;

  /// want | reading | finished
  final String status;
  final int? totalPages;
  final int currentPage;
  final List<BookNote> notes;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Book copyWith({
    String? title,
    String? author,
    String? category,
    String? status,
    Object? totalPages = _keep,
    int? currentPage,
    List<BookNote>? notes,
    Object? startedAt = _keep,
    Object? finishedAt = _keep,
    DateTime? updatedAt,
  }) =>
      Book(
        id: id,
        userId: userId,
        title: title ?? this.title,
        author: author ?? this.author,
        category: category ?? this.category,
        status: status ?? this.status,
        totalPages: identical(totalPages, _keep) ? this.totalPages : totalPages as int?,
        currentPage: currentPage ?? this.currentPage,
        notes: notes ?? this.notes,
        startedAt: identical(startedAt, _keep) ? this.startedAt : startedAt as DateTime?,
        finishedAt: identical(finishedAt, _keep) ? this.finishedAt : finishedAt as DateTime?,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'title': title,
        'author': author,
        'category': category,
        'status': status,
        'totalPages': totalPages,
        'currentPage': currentPage,
        'notes': notes.map((n) => n.toJson()).toList(),
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'finishedAt': finishedAt?.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Book.fromJson(Map<String, dynamic> j) {
    DateTime? opt(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final status = j['status'];
    final total = j['totalPages'];
    final cur = j['currentPage'];
    return Book(
      id: j['id'] as String,
      userId: j['userId'] as String,
      title: (j['title'] as String?) ?? '',
      author: (j['author'] as String?) ?? '',
      category: (j['category'] as String?) ?? '',
      status: status is String && kBookStatuses.contains(status) ? status : 'want',
      totalPages: total is int && total >= 1 && total <= kBookMaxPages ? total : null,
      currentPage: cur is int && cur >= 0 && cur <= kBookMaxPages ? cur : 0,
      notes: j['notes'] is List
          ? (j['notes'] as List<dynamic>).map(BookNote.tryParse).whereType<BookNote>().toList()
          : const <BookNote>[],
      startedAt: opt(j['startedAt']),
      finishedAt: opt(j['finishedAt']),
      createdAt: opt(j['createdAt']) ?? DateTime.now(),
      updatedAt: opt(j['updatedAt']) ?? DateTime.now(),
    );
  }
}

const Object _keep = Object();
