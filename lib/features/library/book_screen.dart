/// كتاب: إنشاء وتعديل (العنوان والمؤلف والتصنيف والحالة والصفحات) وملاحظاته.
library glowara.feature.book;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/library_models.dart';
import 'package:glowara/core/repositories/library_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/library/library_screen.dart';

class BookScreen extends StatefulWidget {
  /// [bookId] = 'new' لكتاب جديد.
  const BookScreen({super.key, required this.bookId});

  final String bookId;

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _author = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _total = TextEditingController();
  final TextEditingController _current = TextEditingController();
  String _status = 'want';
  Book? _book;
  bool _didLoad = false;
  bool _loading = true;
  bool _missing = false;

  bool get _isNew => widget.bookId == 'new' && _book == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _category.dispose();
    _total.dispose();
    _current.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.bookId != 'new') {
      final state = AppState.of(context);
      final b = await LibraryRepository(state.db).byId(state.userId, widget.bookId);
      if (!mounted) return;
      if (b == null) {
        setState(() {
          _missing = true;
          _loading = false;
        });
        return;
      }
      _fill(b);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _fill(Book b) {
    _book = b;
    _title.text = b.title;
    _author.text = b.author;
    _category.text = b.category;
    _total.text = b.totalPages?.toString() ?? '';
    _current.text = b.currentPage > 0 ? b.currentPage.toString() : '';
    _status = b.status;
  }

  void _msg(String key) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  Future<void> _save() async {
    final state = AppState.of(context);
    if (_title.text.trim().isEmpty) {
      _msg('lbTitleRequired');
      return;
    }
    final wasNew = _book == null;
    final saved = await LibraryRepository(state.db).save(
      userId: state.userId,
      id: _book?.id,
      title: _title.text,
      author: _author.text,
      category: _category.text,
      status: _status,
      totalPages: int.tryParse(_total.text.trim()),
      currentPage: int.tryParse(_current.text.trim()) ?? 0,
    );
    if (!mounted) return;
    _msg('lbSaved');
    if (wasNew) {
      // يبقى في الصفحة ليضيف ملاحظات.
      setState(() => _fill(saved));
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final state = AppState.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(context.tr('lbDeleteConfirm')),
        actions: <Widget>[
          TextButton(key: const Key('lb-delete-no'), onPressed: () => Navigator.of(d).pop(false), child: Text(context.tr('cancel'))),
          FilledButton(key: const Key('lb-delete-yes'), onPressed: () => Navigator.of(d).pop(true), child: Text(context.tr('lbDelete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await LibraryRepository(state.db).delete(state.userId, _book!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addNote() async {
    final state = AppState.of(context);
    final text = TextEditingController();
    final page = TextEditingController();
    var kind = 'note';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(context.tr('lbNotes')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    for (final k in kNoteKinds)
                      ChoiceChip(
                        key: Key('lb-kind-$k'),
                        label: Text(context.tr(_kindKey(k))),
                        selected: kind == k,
                        onSelected: (_) => setD(() => kind = k),
                      ),
                  ],
                ),
                TextField(
                  key: const Key('lb-note-text'),
                  controller: text,
                  maxLines: 4,
                  maxLength: kBookNoteMax,
                  decoration: InputDecoration(labelText: context.tr('lbNoteText')),
                ),
                TextField(
                  key: const Key('lb-note-page'),
                  controller: page,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: context.tr('lbNotePage')),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(key: const Key('lb-note-cancel'), onPressed: () => Navigator.of(d).pop(false), child: Text(context.tr('cancel'))),
            FilledButton(key: const Key('lb-note-save'), onPressed: () => Navigator.of(d).pop(true), child: Text(context.tr('save'))),
          ],
        ),
      ),
    );
    final value = text.text;
    final pageNo = int.tryParse(page.text.trim());
    // المتحكّمات بلا مستمعين؛ لا dispose لأن حركة الإغلاق ما زالت تبني الحقول.
    if (ok != true || value.trim().isEmpty || !mounted) return;
    try {
      final b = await LibraryRepository(state.db).addNote(
        userId: state.userId,
        bookId: _book!.id,
        kind: kind,
        text: value,
        page: pageNo,
      );
      if (mounted) setState(() => _book = b);
    } on StateError {
      if (mounted) _msg('lbNoteLimit');
    }
  }

  Future<void> _removeNote(BookNote n) async {
    final state = AppState.of(context);
    final b = await LibraryRepository(state.db).deleteNote(userId: state.userId, bookId: _book!.id, noteId: n.id);
    if (mounted) setState(() => _book = b);
  }

  String _kindKey(String k) => k == 'quote' ? 'lbKindQuote' : (k == 'summary' ? 'lbKindSummary' : 'lbKindNote');

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return GlowPage(
      title: context.tr(_isNew ? 'lbNewTitle' : 'lbEdit'),
      child: _missing
          ? Center(child: Text(context.tr('lbNotFound'), key: const Key('lb-missing')))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: <Widget>[
                    TextField(
                      key: const Key('lb-title'),
                      controller: _title,
                      maxLength: kBookTitleMax,
                      decoration: InputDecoration(labelText: context.tr('lbBookTitle'), counterText: ''),
                    ),
                    TextField(
                      key: const Key('lb-author'),
                      controller: _author,
                      maxLength: kBookAuthorMax,
                      decoration: InputDecoration(labelText: context.tr('lbAuthor'), counterText: ''),
                    ),
                    TextField(
                      key: const Key('lb-category'),
                      controller: _category,
                      maxLength: kBookCategoryMax,
                      decoration: InputDecoration(labelText: context.tr('lbCategory'), counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    Text(context.tr('lbStatus')),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        for (final s in kBookStatuses)
                          ChoiceChip(
                            key: Key('lb-set-$s'),
                            label: Text(context.tr(bookStatusKey(s))),
                            selected: _status == s,
                            onSelected: (_) => setState(() => _status = s),
                          ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            key: const Key('lb-current'),
                            controller: _current,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(labelText: context.tr('lbCurrentPage')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const Key('lb-total'),
                            controller: _total,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(labelText: context.tr('lbTotalPages')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(key: const Key('lb-save'), onPressed: _save, child: Text(context.tr('save'))),
                    const SizedBox(height: 20),
                    Text(context.tr('lbNotes'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (_book == null)
                      Text(context.tr('lbSaveFirst'), key: const Key('lb-save-first'), style: TextStyle(color: c.onSurfaceVariant))
                    else ...<Widget>[
                      if (_book!.notes.isEmpty)
                        Text(context.tr('lbNoNotes'), style: TextStyle(color: c.onSurfaceVariant)),
                      for (final n in _book!.notes)
                        GlowCard(
                          key: Key('lb-note-${n.id}'),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      context.tr(_kindKey(n.kind)) + (n.page == null ? '' : ' · ${n.page}'),
                                      style: TextStyle(fontSize: 11, color: c.primary),
                                    ),
                                    Text(n.text),
                                  ],
                                ),
                              ),
                              IconButton(
                                key: Key('lb-note-del-${n.id}'),
                                tooltip: context.tr('lbDeleteNote'),
                                onPressed: () => _removeNote(n),
                                icon: const Icon(Icons.delete_outline, size: 18),
                              ),
                            ],
                          ),
                        ),
                      TextButton.icon(
                        key: const Key('lb-add-note'),
                        onPressed: _addNote,
                        icon: const Icon(Icons.add),
                        label: Text(context.tr('lbAddNote')),
                      ),
                      TextButton(key: const Key('lb-delete'), onPressed: _delete, child: Text(context.tr('lbDelete'))),
                    ],
                  ],
                ),
    );
  }
}
