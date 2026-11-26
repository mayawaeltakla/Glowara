/// تخصيص الرئيسية: إظهار أقسامها وإخفاؤها وترتيبها. يُحفظ كل تغيير فورًا على هذا
/// الجهاز. الإخفاء لا يحذف بيانات ذلك القسم.
library glowara.feature.customize_home;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/home_layout.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';

String homeSectionLabelKey(String id) {
  switch (id) {
    case 'dayGlow':
      return 'dayGlow';
    case 'water':
      return 'waterToday';
    case 'corners':
      return 'homeCorners';
    case 'mood':
      return 'hcMood';
    case 'tasks':
      return 'tasksToday';
    case 'habits':
      return 'habitsToday';
    default:
      return 'worshipToday';
  }
}

class CustomizeHomeScreen extends StatefulWidget {
  const CustomizeHomeScreen({super.key});

  @override
  State<CustomizeHomeScreen> createState() => _CustomizeHomeScreenState();
}

class _CustomizeHomeScreenState extends State<CustomizeHomeScreen> {
  HomeLayout _layout = HomeLayout.defaults;
  bool _didLoad = false;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  Future<void> _load() async {
    final state = AppState.of(context);
    final raw = await state.settings.get<String>(homeLayoutKey(state.userId));
    if (!mounted) return;
    setState(() {
      _layout = HomeLayout.parse(raw);
      _loading = false;
    });
  }

  Future<void> _apply(HomeLayout next) async {
    final state = AppState.of(context);
    setState(() => _layout = next);
    // التخطيط الافتراضي لا يُخزَّن (يُمسح المفتاح).
    await state.settings.set(homeLayoutKey(state.userId), next.isDefault ? null : next.toStorage());
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return GlowPage(
      title: context.tr('hcTitle'),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: <Widget>[
                Text(context.tr('hcNote'), key: const Key('hc-note'), style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, height: 1.6)),
                const SizedBox(height: 12),
                for (var i = 0; i < _layout.order.length; i++) _row(_layout.order[i], i, c),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('hc-reset'),
                  onPressed: _layout.isDefault ? null : () => _apply(HomeLayout.defaults),
                  child: Text(context.tr('hcReset')),
                ),
              ],
            ),
    );
  }

  Widget _row(String id, int index, ColorScheme c) {
    final visible = !_layout.hidden.contains(id);
    return GlowCard(
      key: Key('hc-row-$id'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Switch(key: Key('hc-switch-$id'), value: visible, onChanged: (_) => _apply(_layout.toggle(id))),
          Expanded(
            child: Text(
              context.tr(homeSectionLabelKey(id)),
              style: TextStyle(fontWeight: FontWeight.w600, color: visible ? c.onSurface : c.onSurfaceVariant),
            ),
          ),
          IconButton(
            key: Key('hc-up-$id'),
            tooltip: context.tr('hcUp'),
            onPressed: index == 0 ? null : () => _apply(_layout.move(id, -1)),
            icon: const Icon(Icons.arrow_upward, size: 18),
          ),
          IconButton(
            key: Key('hc-down-$id'),
            tooltip: context.tr('hcDown'),
            onPressed: index == _layout.order.length - 1 ? null : () => _apply(_layout.move(id, 1)),
            icon: const Icon(Icons.arrow_downward, size: 18),
          ),
        ],
      ),
    );
  }
}
