/// المزاج والمذكرات: بيانات خاصة مع قفل PIN اختياري.
library glowara.feature.journal;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  bool _didLoad = false;
  bool _loading = true;
  bool _unlocked = false;
  final _pin = TextEditingController();
  String? _pinError;

  MoodEntry? _todayMood;
  List<MoodEntry> _moods = <MoodEntry>[];
  List<JournalEntry> _journals = <JournalEntry>[];
  int _moodValue = 3;
  final _moodNote = TextEditingController();
  final _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    _moodNote.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    if (state.pinSet && !_unlocked) {
      // لا نستخدم setState هنا: قد تُستدعى أثناء didChangeDependencies،
      // والبناء سيحدث مباشرة بعدها. مجرد إيقاف مؤشر التحميل يكفي.
      _loading = false;
      return;
    }
    final now = DateTime.now();
    final mood = await state.journal.moodFor(state.userId, now);
    final moods = await state.journal.moods(
      state.userId,
      from: now.subtract(const Duration(days: 14)),
      to: now,
    );
    final journals = await state.journal.journals(state.userId);
    if (!mounted) return;
    setState(() {
      _todayMood = mood;
      _moods = moods.reversed.toList();
      _journals = journals;
      if (mood != null) {
        _moodValue = mood.value;
        _moodNote.text = mood.note ?? '';
      }
      _loading = false;
    });
  }

  Future<void> _unlock() async {
    final state = AppState.of(context);
    final ok = await state.verifyPin(_pin.text);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _unlocked = true;
        _pinError = null;
        _pin.clear();
        _loading = true;
      });
      _load();
    } else {
      setState(() => _pinError = context.tr('wrongPin'));
    }
  }

  String _moodLabel(BuildContext context, int value) {
    switch (value) {
      case 5:
        return context.tr('moodGreat');
      case 4:
        return context.tr('moodGood');
      case 3:
        return context.tr('moodOkay');
      case 2:
        return context.tr('moodLow');
      default:
        return context.tr('moodBad');
    }
  }

  String _moodEmoji(int value) {
    switch (value) {
      case 5:
        return '😄';
      case 4:
        return '🙂';
      case 3:
        return '😐';
      case 2:
        return '😔';
      default:
        return '😞';
    }
  }

  Future<void> _saveMood() async {
    final state = AppState.of(context);
    await state.journal.saveMood(
      userId: state.userId,
      day: DateTime.now(),
      value: _moodValue,
      note: _moodNote.text.trim().isEmpty ? null : _moodNote.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('moodSaved'))),
    );
    _load();
  }

  Future<void> _openJournalEditor([JournalEntry? entry]) async {
    final state = AppState.of(context);
    final title = TextEditingController(text: entry?.title ?? '');
    final content = TextEditingController(text: entry?.content ?? '');
    final l10n = context.l10n;
    final result = await showModalBottomSheet<JournalEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.glowColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(sheetContext).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
              Text(
                entry == null ? context.tr('addJournal') : l10n.edit,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                autofocus: entry == null,
                decoration: InputDecoration(labelText: context.tr('journalEntryTitle')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: content,
                minLines: 5,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: context.tr('journalContent'),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(null),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final text = title.text.trim();
                        if (text.isEmpty) return;
                        final now = DateTime.now();
                        Navigator.of(sheetContext).pop(
                          JournalEntry(
                            id: entry?.id ?? uniqueId(),
                            userId: state.userId,
                            title: text,
                            content: content.text.trim(),
                            createdAt: entry?.createdAt ?? now,
                            updatedAt: now,
                            syncStatus: SyncStatus.local,
                            lastModified: now,
                          ),
                        );
                      },
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
    if (result == null || !mounted) {
      title.dispose();
      content.dispose();
      return;
    }
    title.dispose();
    content.dispose();
    await state.journal.saveJournal(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.savedLocally)),
    );
    _load();
  }

  Future<void> _deleteJournal(JournalEntry entry) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('deleteJournalConfirm'),
      message: context.l10n.confirmDeleteSub,
    );
    if (!ok || !mounted) return;
    final state = AppState.of(context);
    await state.journal.deleteJournal(entry.id);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final c = context.glowColors;
    final l10n = context.l10n;

    if (_loading) {
      return GlowPage(
        title: l10n.journal,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.pinSet && !_unlocked) {
      return GlowPage(
        title: l10n.journal,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.lock_outline, size: 48, color: c.primary),
                const SizedBox(height: 14),
                Text(
                  context.tr('pinPrompt'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: context.tr('enterPin'),
                    errorText: _pinError,
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _unlock,
                    child: Text(context.tr('enterPin')),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('journalPrivateHint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filtered = _search.text.trim().isEmpty
        ? _journals
        : _journals.where((j) {
            final q = _search.text.trim().toLowerCase();
            return j.title.toLowerCase().contains(q) || j.content.toLowerCase().contains(q);
          }).toList();

    return DefaultTabController(
      length: 2,
      child: GlowPage(
        title: l10n.journal,
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: <Widget>[
                  Icon(Icons.lock, size: 14, color: c.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr('privateNote'),
                      style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              labelColor: c.primary,
              unselectedLabelColor: c.onSurfaceVariant,
              indicatorColor: c.primary,
              tabs: <Widget>[
                Tab(icon: const Icon(Icons.mood_outlined), text: l10n.mood),
                Tab(icon: const Icon(Icons.edit_note), text: context.tr('myJournals')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _buildMoodTab(context),
                  _buildJournalsTab(context, filtered),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodTab(BuildContext context) {
    final c = context.glowColors;
    final locale = Localizations.localeOf(context).languageCode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    _moodEmoji(_moodValue),
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('howAreYou'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <int>[5, 4, 3, 2, 1].map((value) {
                  return _MoodChip(
                    emoji: _moodEmoji(value),
                    label: _moodLabel(context, value),
                    selected: _moodValue == value,
                    onTap: () => setState(() => _moodValue = value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _moodNote,
                maxLines: 2,
                decoration: InputDecoration(labelText: context.tr('moodNote')),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveMood,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(context.tr('saveMood')),
                ),
              ),
              if (_todayMood != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '${context.tr('moodToday')}: ${_moodLabel(context, _todayMood!.value)}',
                  style: TextStyle(fontSize: 12, color: c.success, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlowSectionTitle(title: context.tr('moodHistory'), icon: Icons.history),
        if (_moods.isEmpty)
          GlowCard(
            child: Text(
              context.tr('noMoodToday'),
              style: TextStyle(color: c.onSurfaceVariant, fontSize: 13),
            ),
          )
        else
          ..._moods.map((mood) {
            final date = DateTime.tryParse(mood.date) ?? DateTime.now();
            return GlowCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: <Widget>[
                  Text(_moodEmoji(mood.value), style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _moodLabel(context, mood.value),
                          style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface),
                        ),
                        Text(
                          formatShortDate(date, locale),
                          style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                        ),
                        if (mood.note != null && mood.note!.isNotEmpty)
                          Text(
                            mood.note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildJournalsTab(BuildContext context, List<JournalEntry> journals) {
    final c = context.glowColors;
    final locale = Localizations.localeOf(context).languageCode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _openJournalEditor(),
              child: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (journals.isEmpty)
          GlowEmptyState(
            icon: Icons.edit_note,
            title: context.tr('noJournals'),
            subtitle: context.tr('noJournalsSub'),
            actionLabel: context.tr('addJournal'),
            onAction: () => _openJournalEditor(),
          )
        else
          ...journals.map((entry) {
            return GlowCard(
              margin: const EdgeInsets.only(bottom: 8),
              onTap: () => _openJournalEditor(entry),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          entry.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: c.onSurface,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _deleteJournal(entry),
                        icon: Icon(Icons.delete_outline, size: 18, color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Text(
                    formatShortDate(entry.updatedAt ?? entry.createdAt, locale),
                    style: TextStyle(fontSize: 10.5, color: c.onSurfaceVariant),
                  ),
                  if (entry.content.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      entry.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.primaryContainer : c.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? c.primary : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: selected ? c.primary : c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
