/// خانة صورة اختيارية لحلم أو ورقة: إضافة، استبدال، حذف. الصورة تبقى على الجهاز.
library glowara.widgets.photo_slot;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/repositories/image_repository.dart';
import 'package:glowara/core/state/app_state.dart';

class PhotoSlot extends StatefulWidget {
  const PhotoSlot({super.key, required this.ownerKind, required this.ownerId});

  final String ownerKind;
  final String ownerId;

  /// للاختبارات: يستبدل نافذة اختيار الملف.
  @visibleForTesting
  static Future<Uint8List?> Function()? debugPicker;

  @override
  State<PhotoSlot> createState() => _PhotoSlotState();
}

class _PhotoSlotState extends State<PhotoSlot> {
  StoredPhoto? _photo;
  bool _loaded = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    final p = await ImageRepository(state.db).get(state.userId, widget.ownerId);
    if (mounted) setState(() => _photo = p);
  }

  Future<Uint8List?> _pick() async {
    final test = PhotoSlot.debugPicker;
    if (test != null) return test();
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    return res?.files.single.bytes;
  }

  Future<void> _add() async {
    final state = AppState.of(context);
    final bytes = await _pick();
    if (bytes == null || !mounted) return;
    final r = await ImageRepository(state.db).set(
      userId: state.userId,
      ownerKind: widget.ownerKind,
      ownerId: widget.ownerId,
      bytes: bytes,
    );
    if (!mounted) return;
    if (r == PhotoResult.saved) {
      setState(() => _error = null);
      await _load();
    } else {
      setState(() => _error = r == PhotoResult.tooLarge ? 'phTooLarge' : 'phNotImage');
    }
  }

  Future<void> _remove() async {
    final state = AppState.of(context);
    await ImageRepository(state.db).remove(state.userId, widget.ownerId);
    if (!mounted) return;
    setState(() {
      _photo = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final p = _photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.tr('phTitle')),
        const SizedBox(height: 6),
        if (p != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              p.bytes,
              key: const Key('photo-image'),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(height: 60, child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        Wrap(
          spacing: 8,
          children: <Widget>[
            TextButton.icon(
              key: const Key('photo-add'),
              onPressed: _add,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(context.tr(p == null ? 'phAdd' : 'phReplace')),
            ),
            if (p != null)
              TextButton(key: const Key('photo-remove'), onPressed: _remove, child: Text(context.tr('phRemove'))),
          ],
        ),
        if (_error != null) Text(context.tr(_error!), key: const Key('photo-error'), style: TextStyle(color: c.error)),
        Text(context.tr('phNote'), style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }
}
