/// قوقعة التطبيق: MaterialApp، التوجيه، الثيم، localisation.
library glowara.app;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/features/auth/auth_screens.dart';
import 'package:glowara/features/calendar/tasks_screen.dart';
import 'package:glowara/features/care/care_screen.dart';
import 'package:glowara/features/habits/habits_screen.dart';
import 'package:glowara/features/health/health_screen.dart';
import 'package:glowara/features/home/home_screen.dart';
import 'package:glowara/features/journal/journal_screen.dart';
import 'package:glowara/features/language/language_screen.dart';
import 'package:glowara/features/language/quiz_screen.dart';
import 'package:glowara/features/more/more_screen.dart';
import 'package:glowara/features/progress/progress_screen.dart';
import 'package:glowara/features/settings/settings_screen.dart';
import 'package:glowara/features/study/study_screen.dart';
import 'package:glowara/features/study/subject_detail_screen.dart';
import 'package:glowara/features/worship/quran_reader_screen.dart';
import 'package:glowara/features/worship/worship_screen.dart';
import 'package:go_router/go_router.dart';

/// التطبيق الرئيسي.
class GlowaraApp extends StatelessWidget {
  const GlowaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final locale = Locale(state.locale, state.locale == 'ar' ? 'AE' : 'US');

    return MaterialApp.router(
      title: 'Glowara',
      routerConfig: _router,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppThemes.material(state.themeId, Brightness.light, locale: state.locale),
      darkTheme: AppThemes.material(state.themeId, Brightness.dark, locale: state.locale),
      themeMode: state.themeMode,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: state.locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// مسارات التطبيق.
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const _AuthGate(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(
      path: '/study',
      builder: (context, state) => const _Protected(child: StudyScreen()),
    ),
    GoRoute(
      path: '/study/:id',
      builder: (context, state) => _Protected(
        child: SubjectDetailScreen(subjectId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/tasks',
      builder: (context, state) => const _Protected(child: TasksScreen()),
    ),
    GoRoute(
      path: '/worship',
      builder: (context, state) => const _Protected(child: WorshipScreen()),
    ),
    GoRoute(
      path: '/care',
      builder: (context, state) => const _Protected(child: CareScreen()),
    ),
    GoRoute(
      path: '/health',
      builder: (context, state) => const _Protected(child: HealthScreen()),
    ),
    GoRoute(
      path: '/journal',
      builder: (context, state) => const _Protected(child: JournalScreen()),
    ),
    GoRoute(
      path: '/language',
      builder: (context, state) => const _Protected(child: LanguageScreen()),
    ),
    GoRoute(
      path: '/language/quiz/:deckId',
      builder: (context, state) => _Protected(
        child: QuizScreen(deckId: state.pathParameters['deckId']!),
      ),
    ),
    GoRoute(
      path: '/progress',
      builder: (context, state) => const _Protected(child: ProgressScreen()),
    ),
    GoRoute(
      path: '/habits',
      builder: (context, state) => const _Protected(child: HabitsScreen()),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const _Protected(child: SettingsScreen()),
    ),
    GoRoute(
      path: '/quran',
      builder: (context, state) => const _Protected(child: QuranReaderScreen()),
    ),
  ],
  initialLocation: '/',
);

class _Protected extends StatelessWidget {
  const _Protected({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.isLoggedIn) return const WelcomeScreen();
    return child;
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.isLoggedIn) return const WelcomeScreen();
    return const HomeShell();
  }
}

/// القوقعة الرئيسية ذات التبويبات الخمسة.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    final pages = <Widget>[
      const HomeScreen(),
      const WorshipScreen(),
      const TasksScreen(),
      const CareScreen(),
      const MoreScreen(),
    ];
    final labels = <String>[l10n.home, l10n.worship, l10n.tasks, l10n.selfCare, l10n.more];
    final icons = <IconData>[
      Icons.spa_outlined,
      Icons.mosque_outlined,
      Icons.task_alt,
      Icons.favorite_border,
      Icons.grid_view_rounded,
    ];
    final selectedIcons = <IconData>[
      Icons.spa,
      Icons.mosque,
      Icons.task_alt,
      Icons.favorite,
      Icons.grid_view_rounded,
    ];

    return Scaffold(
      backgroundColor: c.scaffold,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _GlowDock(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
        labels: labels,
        icons: icons,
        selectedIcons: selectedIcons,
      ),
    );
  }
}

/// شريط التنقل العائم: كبسولة مرتفعة عن الحافة بظل موف ناعم، ونقطة ذهبية
/// تحت التبويب النشط.
class _GlowDock extends StatelessWidget {
  const _GlowDock({
    required this.index,
    required this.onSelect,
    required this.labels,
    required this.icons,
    required this.selectedIcons,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> selectedIcons;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final light = Theme.of(context).brightness == Brightness.light;
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: light ? 0.94 : 0.96),
                borderRadius: BorderRadius.circular(GlowRadius.sheet),
                border: Border.all(
                  color: light ? Colors.white.withValues(alpha: 0.7) : c.border,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: c.primary.withValues(alpha: light ? 0.14 : 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SizedBox(
                height: 68,
                child: Row(
                  children: List<Widget>.generate(
                    labels.length,
                    (i) => Expanded(
                      child: _DockItem(
                        label: labels[i],
                        icon: i == index ? selectedIcons[i] : icons[i],
                        selected: i == index,
                        onTap: () => onSelect(i),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final color = selected ? c.primary : c.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: selected ? 16 : 4,
              height: 4,
              decoration: BoxDecoration(
                color: selected ? c.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(color: c.gold.withValues(alpha: 0.6), blurRadius: 6),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
