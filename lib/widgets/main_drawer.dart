// lib/widgets/main_drawer.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/project.dart';
import '../models/role.dart';
import '../state/app_state.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appState = context.watch<AppState>();
    final projects = appState.projects;
    final Project? activeProject = appState.activeProject;
    final role = appState.activeProjectRole ?? Role.tester;
    final canCreateBug = can(role, Permission.createBug);
    final canViewStats = can(role, Permission.viewStats);
    final canViewAll = can(role, Permission.viewAllBugs);
    final isAdmin = role == Role.admin;
    final currentUser = appState.currentUser;
    final profileSubtitle = currentUser == null
        ? null
        : (currentUser.displayName.isNotEmpty ? currentUser.displayName : currentUser.email);

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(l10n.t('app.title'), style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 12),
                if (projects.isNotEmpty)
                  DropdownButton<String>(
                    value: activeProject?.id ?? projects.first.id,
                    hint: Text(l10n.t('projects.title')),
                    isExpanded: true,
                    items: [
                      for (final project in projects)
                        DropdownMenuItem(
                          value: project.id,
                          child: Text(project.name.isEmpty ? l10n.t('projects.untitled') : project.name),
                        ),
                    ],
                    onChanged: (value) {
                      context.read<AppState>().setActiveProject(value);
                      Navigator.pop(context);
                    },
                  )
                else
                  Text(l10n.t('home.noProject')),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.workspaces),
            title: Text(l10n.t('drawer.projects')),
            onTap: () {
              Navigator.pop(context);
              context.go('/projects');
            },
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text(l10n.t('drawer.board')),
            onTap: () {
              Navigator.pop(context);
              context.go('/home');
            },
          ),
          if (canCreateBug)
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.t('drawer.newBug')),
              onTap: () {
                Navigator.pop(context);
                context.go('/new');
              },
            ),
          if (canViewStats)
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: Text(l10n.t('drawer.stats')),
              onTap: () {
                Navigator.pop(context);
                context.go('/stats');
              },
            ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: Text(l10n.t('drawer.admin')),
              onTap: () {
                Navigator.pop(context);
                context.go('/admin');
              },
            ),
          const Divider(),
          if (canViewAll)
            ListTile(
              leading: const Icon(Icons.filter_alt),
              title: Text(l10n.t('drawer.myBugs')),
              onTap: () {
                Navigator.pop(context);
                context.go('/home?filter=mine');
              },
            ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: Text(l10n.t('drawer.high')),
            onTap: () {
              Navigator.pop(context);
              context.go('/home?filter=high');
            },
          ),
          ListTile(
            leading: const Icon(Icons.update),
            title: Text(l10n.t('drawer.new24')),
            onTap: () {
              Navigator.pop(context);
              context.go('/home?filter=new');
            },
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(l10n.t('drawer.due')),
            onTap: () {
              Navigator.pop(context);
              context.go('/home?filter=due');
            },
          ),
          ListTile(
            leading: const Icon(Icons.label),
            title: Text(l10n.t('drawer.labels')),
            onTap: () {
              Navigator.pop(context);
              context.go('/home?filter=labels');
            },
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(l10n.t('drawer.components')),
              onTap: () {
                Navigator.pop(context);
                context.go('/home?filter=components');
              },
            ),
          const Divider(),
          if (isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(l10n.t('drawer.exportCsv')),
              onTap: () {
                Navigator.pop(context);
                context.go('/home?action=export_csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(l10n.t('drawer.exportPdf')),
              onTap: () {
                Navigator.pop(context);
                context.go('/home?action=export_pdf');
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(l10n.t('drawer.notifications')),
            onTap: () {}, // открой настройки FCM
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.t('drawer.profile')),
            subtitle: profileSubtitle != null ? Text(profileSubtitle) : null,
            onTap: () {
              Navigator.pop(context);
              context.go('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(l10n.t('drawer.settings')),
            onTap: () {
              Navigator.pop(context);
              context.go('/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.t('drawer.logout')),
            onTap: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              context.go('/');
            },
          ),
        ],
      ),
    );
  }
}
