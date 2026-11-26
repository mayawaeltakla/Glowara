/// مكتبتي: قائمة الكتب بتصفية حسب الحالة والتصنيف. بلا نسب ولا أهداف.
library glowara.feature.library;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/library_models.dart';
import 'package:glowara/core/repositories/library_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:go_router/go_router.dart';

String bookStatusKey(String status) {
  switch (status) {
    case 'reading':
      return 'lbReading';
    case 'finished':
      return 'lbFinished';
    default:
      return 'lbWant';
  }
}

/// سطر موضع القراءة بالصفحات فقط (بلا نسبة).
String bookPageLine(BuildContext context, Book b) {
  if (b.currentPage <= 0) return '';
  final t = b.totalPages;
  return t == null
      ? context.tr('lbPageAt').replaceAll('{c}', '${b.currentPage}')
      : context.tr('lbPageOf').replaceAll('{c}', '${b.currentPage}').replaceAll('{t}', '$t');
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _didLoad = false;
  bool _loading = true;
  Object? _error;
  List<Book> _books = const <Book>[];
  String? _status;
  String? _category;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    try {
      final books = await LibraryRepository(state.db).all(state.userId);
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _open(String id) async {
    await context.push('/library/book/$id');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final categories = (<String>{for (final b in _books) if (b.category.isNotEmpty) b.category}.toList()..sort());
    if (_category != null && !categories.contains(_category)) _category = null;
    final shown = _books
        .where((b) => (_status == null || b.status == _status) && (_category == null || b.category == _category))
        .toList();
    return GlowPage(
      title: context.tr('lbTitle'),
      fab: FloatingActionButton.extended(
        key: const Key('lb-add'),
        onPressed: () => _open('new'),
        icon: const Icon(Icons.add),
        label: Text(context.tr('lbAdd')),
      ),
      child: _error != null
          ? GlowErrorView(message: context.tr('lbLoadError'), onRetry: _load)
          : ListView(
              children: <Widget>[
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Text(
                  context.tr('lbNote'),
                  key: const Key('lb-note'),
                  style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 12),
                if (_books.isNotEmpty) ...<Widget>[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      ChoiceChip(
                        key: const Key('lb-status-all'),
                        label: Text(context.tr('lbAll')),
                        selected: _status == null,
                        onSelected: (_) => setState(() => _status = null),
                      ),
                      for (final s in kBookStatuses)
                        ChoiceChip(
                          key: Key('lb-status-$s'),
                          label: Text(context.tr(bookStatusKey(s))),
                          selected: _status == s,
                          onSelected: (_) => setState(() => _status = s),
                        ),
                    ],
                  ),
                  if (categories.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final cat in categories)
                          FilterChip(
                            key: Key('lb-cat-$cat'),
                            label: Text(cat),
                            selected: _category == cat,
                            onSelected: (on) => setState(() => _category = on ? cat : null),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                if (!_loading && _books.isEmpty)
                  Text(context.tr('lbEmpty'), key: const Key('lb-empty'), style: TextStyle(color: c.onSurfaceVariant)),
                if (_books.isNotEmpty && shown.isEmpty)
                  Text(context.tr('lbEmptyFilter'), key: const Key('lb-empty-filter'), style: TextStyle(color: c.onSurfaceVariant)),
                for (final b in shown)
                  GlowCard(
                    key: Key('lb-book-${b.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _open(b.id),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(b.title, style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                                if (b.author.isNotEmpty)
                                  Text(b.author, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                                Text(
                                  <String>[
                                    context.tr(bookStatusKey(b.status)),
                                    if (b.status == 'reading' && bookPageLine(context, b).isNotEmpty) bookPageLine(context, b),
                                    if (b.category.isNotEmpty) b.category,
                                  ].join(' · '),
                                  style: TextStyle(fontSize: 12, color: c.primary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: c.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 72),
              ],
            ),
    );
  }
}
