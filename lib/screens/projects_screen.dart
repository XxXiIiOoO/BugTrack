import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/role_labels.dart';
import '../models/UserData.dart';
import '../models/project.dart';
import '../models/role.dart';
import '../service/project_service.dart';
import '../state/app_state.dart';
import '../widgets/main_drawer.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appState = context.watch<AppState>();
    final projects = appState.projects;
    final activeId = appState.activeProjectId;
    final currentUser = appState.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('projects.title'))),
      drawer: const MainDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: currentUser == null || _creating ? null : () => _showCreateProjectDialog(context, currentUser),
        icon: _creating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
        label: Text(l10n.t('projects.create')),
      ),
      body: projects.isEmpty
          ? Center(child: Text(l10n.t('projects.none')))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final project = projects[index];
                final isActive = project.id == activeId;
                final role = project.memberRoles[currentUser?.id];
                return ListTile(
                  title: Text(project.name.isEmpty ? l10n.t('projects.untitled') : project.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (project.description.isNotEmpty) Text(project.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(
                        role == null ? l10n.t('projects.roleUnknown') : roleLabel(l10n, role),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  leading: Icon(isActive ? Icons.radio_button_checked : Icons.radio_button_off),
                  trailing: role == Role.admin
                      ? IconButton(
                          tooltip: l10n.t('projects.manageMembers'),
                          icon: const Icon(Icons.group),
                          onPressed: () => context.push('/projects/${project.id}/members'),
                        )
                      : null,
                  onTap: () {
                    context.read<AppState>().setActiveProject(project.id);
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/home');
                    }
                  },
                );
              },
            ),
    );
  }

  Future<void> _showCreateProjectDialog(BuildContext context, UserData owner) async {
    final l10n = context.l10n;
    _nameCtrl.clear();
    _descriptionCtrl.clear();

    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('projects.create')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.t('projects.nameHint')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionCtrl,
              decoration: InputDecoration(labelText: l10n.t('projects.descriptionHint')),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('confirm.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('common.save')),
          ),
        ],
      ),
    );
    if (result != true) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('validation.required'))),
        );
      }
      return;
    }

    setState(() => _creating = true);
    try {
      final project = await ProjectService.instance.createProject(
        owner: owner,
        name: name,
        description: _descriptionCtrl.text.trim(),
      );
      context.read<AppState>().setActiveProject(project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('projects.created', params: {'name': project.name.isEmpty ? l10n.t('projects.untitled') : project.name}))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('common.error', params: {'error': '$e'}))),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
