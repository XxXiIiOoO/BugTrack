import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'models/role.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/bug_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/new_bug_screen.dart';
import 'screens/new_user_screen.dart';
import 'screens/project_members_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/register_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/edit_user_screen.dart';
import 'screens/user_profile_screen.dart';
import 'state/app_state.dart';

/// Именованные маршруты для GoRouter.
class AppRoutes {
  static const login = '/';
  static const register = '/register';
  static const home = '/home';
  static const bug = '/bug'; // фактический путь: /bug/:id
  static const newBug = '/new';
  static const stats = '/stats';
  static const admin = '/admin';
  static const adminUsersNew = '/admin/users/new';
  static const adminUsersEdit = '/admin/users/:uid/edit';
  static const projects = '/projects';
  static const projectMembers = '/projects/:id/members';
  static const settings = '/settings';
  static const profile = '/profile';

  static String bugById(String id) => '$bug/$id';
  static String adminEditUser(String uid) => '/admin/users/$uid/edit';
}

class AppRouter {
  AppRouter({required this.appState});

  final AppState appState;

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: appState,
    redirect: (context, state) => _handleRedirect(state),
    routes: <GoRoute>[
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, state) => HomeScreen(
          filter: state.uri.queryParameters['filter'],
          action: state.uri.queryParameters['action'],
        ),
      ),
      GoRoute(
        path: AppRoutes.newBug,
        builder: (context, __) {
          final appState = context.watch<AppState>();
          final role = appState.activeProjectRole;
          if (role == null) {
            return appState.projects.isEmpty ? const _LoadingScreen() : const _ForbiddenScreen();
          }
          if (can(role, Permission.createBug)) {
            return const NewBugScreen();
          }
          return const _ForbiddenScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.stats,
        builder: (context, __) {
          final appState = context.watch<AppState>();
          final role = appState.activeProjectRole;
          if (role == null) {
            return appState.projects.isEmpty ? const _LoadingScreen() : const _ForbiddenScreen();
          }
          if (can(role, Permission.viewStats)) {
            return const StatsScreen();
          }
          return const _ForbiddenScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const UserProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, __) {
          final appState = context.watch<AppState>();
          final role = appState.currentUser?.role;
          if (role == null) {
            return const _LoadingScreen();
          }
          if (role == Role.admin) {
            return const AdminPanelScreen();
          }
          return const _ForbiddenScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.adminUsersNew,
        builder: (context, __) {
          final role = context.watch<AppState>().currentUser?.role;
          if (role == null) return const _LoadingScreen();
          if (role == Role.admin) return const NewUserScreen();
          return const _ForbiddenScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.adminUsersEdit,
        builder: (context, state) {
          final role = context.watch<AppState>().currentUser?.role;
          if (role == null) return const _LoadingScreen();
          if (role != Role.admin) return const _ForbiddenScreen();
          final uid = state.pathParameters['uid'];
          if (uid == null || uid.isEmpty) {
            return const _ForbiddenScreen();
          }
          return EditUserScreen(uid: uid);
        },
      ),
      GoRoute(
        path: AppRoutes.projects,
        builder: (_, __) => const ProjectsScreen(),
      ),
      GoRoute(
        path: AppRoutes.projectMembers,
        builder: (context, state) {
          final projectId = state.pathParameters['id'];
          if (projectId == null || projectId.isEmpty) {
            return const _ForbiddenScreen();
          }
          final appState = context.watch<AppState>();
          final role = appState.roleForProject(projectId);
          if (role == null) {
            return appState.projects.isEmpty ? const _LoadingScreen() : const _ForbiddenScreen();
          }
          if (role != Role.admin) return const _ForbiddenScreen();
          return ProjectMembersScreen(projectId: projectId);
        },
      ),
      GoRoute(
        path: '${AppRoutes.bug}/:id',
        builder: (_, state) => BugDetailScreen(
          bugId: state.pathParameters['id'] ?? '',
          projectId: state.uri.queryParameters['project'],
        ),
      ),
    ],
  );

  String? _handleRedirect(GoRouterState state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final loggingIn = state.matchedLocation == AppRoutes.login;
    final registering = state.matchedLocation == AppRoutes.register;

    if (!loggedIn && !loggingIn && !registering) {
      return AppRoutes.login;
    }

    if (loggedIn && (loggingIn || registering)) {
      return AppRoutes.home;
    }

    return null;
  }
}

class _ForbiddenScreen extends StatelessWidget {
  const _ForbiddenScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('forbidden.title'))),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.t('forbidden.message')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(l10n.t('forbidden.home')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
