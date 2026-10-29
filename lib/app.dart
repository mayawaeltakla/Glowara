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
      theme: AppThemes.material(state.themeId, Brightness.light),
      darkTheme: AppThemes.material(state.themeId, Brightness.dark),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: c.surface,
        indicatorColor: c.primaryContainer,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: List<NavigationDestination>.generate(
          5,
          (i) => NavigationDestination(
            icon: Icon(icons[i]),
            selectedIcon: Icon(selectedIcons[i], color: c.primary),
            label: labels[i],
          ),
        ),
      ),
    );
  }
}
