/// شاشة "المزيد": مدخل لكل أقسام التطبيق.
library glowara.feature.more;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:go_router/go_router.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final state = AppState.of(context);

    final sections = <_MoreEntry>[
      _MoreEntry(
        icon: Icons.menu_book,
        title: context.tr('sectionStudy'),
        subtitle: context.tr('studyProgress'),
        route: '/study',
      ),
      _MoreEntry(
        icon: Icons.spa,
        title: context.tr('sectionCare'),
        subtitle: context.tr('morningRoutine'),
        route: '/care',
      ),
      _MoreEntry(
        icon: Icons.water_drop,
        title: context.tr('sectionHealth'),
        subtitle: context.tr('waterTitle'),
        route: '/health',
      ),
      _MoreEntry(
        icon: Icons.edit_note,
        title: context.tr('sectionJournal'),
        subtitle: context.tr('myJournals'),
        route: '/journal',
      ),
      _MoreEntry(
        icon: Icons.translate,
        title: context.tr('sectionLanguage'),
        subtitle: context.tr('decks'),
        route: '/language',
      ),
      _MoreEntry(
        icon: Icons.insights,
        title: context.tr('sectionProgress'),
        subtitle: context.tr('achievementRate'),
        route: '/progress',
      ),
      _MoreEntry(
        icon: Icons.emoji_objects,
        title: context.tr('sectionHabits'),
        subtitle: context.tr('todayHabits'),
        route: '/habits',
      ),
      _MoreEntry(
        icon: Icons.settings,
        title: context.tr('sectionSettings'),
        subtitle: context.tr('appearance'),
        route: '/settings',
      ),
    ];

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        title: Text(l10n.more),
        backgroundColor: c.scaffold,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: <Widget>[
            GlowCard(
              gradient: c.heroGradient,
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Text(
                      (state.user?.displayName?.trim().isNotEmpty ?? false)
                          ? state.user!.displayName!.trim().substring(0, 1)
                          : 'G',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          state.user?.displayName ?? l10n.welcome,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.user?.email ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: context.tr('sectionSettings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('moreSub'),
              style: TextStyle(color: c.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sections.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.25,
              ),
              itemBuilder: (context, index) {
                final entry = sections[index];
                return GlowCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => context.push(entry.route),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(entry.icon, color: c.primary, size: 20),
                      ),
                      const Spacer(),
                      Text(
                        entry.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.onSurface,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreEntry {
  const _MoreEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}
