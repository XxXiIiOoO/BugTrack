import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/role_labels.dart';
import '../models/UserData.dart';
import '../models/project.dart';
import '../models/role.dart';
import '../service/project_service.dart';
import '../state/app_state.dart';
import '../widgets/main_drawer.dart';

class ProjectMembersScreen extends StatefulWidget {
  final String projectId;
  const ProjectMembersScreen({super.key, required this.projectId});

  @override
  State<ProjectMembersScreen> createState() => _ProjectMembersScreenState();
}

class _ProjectMembersScreenState extends State<ProjectMembersScreen> {
  final _emailCtrl = TextEditingController();
  Role _selectedRole = Role.tester;
  bool _processing = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appState = context.watch<AppState>();
    final project = appState.projects.firstWhere(
      (p) => p.id == widget.projectId,
      orElse: () => Project(
        id: '',
        name: '',
        description: '',
        ownerId: '',
        memberIds: const <String>[],
        memberRoles: const <String, Role>{},
        createdAt: DateTime.now(),
      ),
    );

    if (project.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('projects.manageMembers'))),
        drawer: const MainDrawer(),
        body: Center(child: Text(l10n.t('projects.notFound'))),
      );
    }

    final currentUserId = appState.currentUser?.id;
    final currentRole = project.memberRoles[currentUserId];
    final isAdmin = currentRole == Role.admin;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('projects.manageMembers'))),
      drawer: const MainDrawer(),
      body: FutureBuilder<List<UserData>>(
        future: _loadMembers(project.memberIds),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snapshot.data ?? const <UserData>[];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name.isEmpty ? l10n.t('projects.untitled') : project.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (project.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(project.description),
                      ),
                  ],
                ),
              ),
              if (isAdmin) _buildInviteRow(context, project),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final memberRole = project.memberRoles[member.id] ?? Role.tester;
                    final isOwner = project.ownerId == member.id;
                    return ListTile(
                      title: Text(member.displayName.isEmpty ? member.email : member.displayName),
                      subtitle: Text(member.email),
                      trailing: isAdmin && !isOwner
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButton<Role>(
                                  value: memberRole,
                                  onChanged: (role) {
                                    if (role == null) return;
                                    _updateRole(project, member.id, role);
                                  },
                                  items: Role.values
                                      .map((role) => DropdownMenuItem<Role>(
                                            value: role,
                                            child: Text(roleLabel(l10n, role)),
                                          ))
                                      .toList(),
                                ),
                                IconButton(
                                  tooltip: l10n.t('projects.removeMember'),
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _removeMember(project, member.id),
                                ),
                              ],
                            )
                          : Text(roleLabel(l10n, memberRole)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInviteRow(BuildContext context, Project project) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('projects.inviteTitle'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.t('projects.inviteEmail'),
                    hintText: 'user@example.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<Role>(
                value: _selectedRole,
                onChanged: (role) => setState(() => _selectedRole = role ?? Role.tester),
                items: Role.values
                    .map(
                      (role) => DropdownMenuItem<Role>(
                        value: role,
                        child: Text(roleLabel(l10n, role)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _processing ? null : () => _inviteMember(project),
                child: _processing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.t('projects.inviteButton')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<UserData>> _loadMembers(List<String> memberIds) async {
    if (memberIds.isEmpty) return const <UserData>[];
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: memberIds.length > 10 ? memberIds.sublist(0, 10) : memberIds)
        .get();

    final users = query.docs.map((doc) => UserData.fromMap(doc.id, doc.data())).toList();
    if (memberIds.length <= 10) return users;

    final remaining = memberIds.skip(10).toList();
    if (remaining.isEmpty) return users;

    users.addAll(await _loadMembers(remaining));
    return users;
  }

  Future<void> _inviteMember(Project project) async {
    final l10n = context.l10n;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('validation.email'))),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final user = await ProjectService.instance.findUserByEmail(email);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('projects.inviteNotFound', params: {'email': email}))),
        );
        return;
      }
      await ProjectService.instance.updateMemberRole(
        project: project,
        userId: user.id,
        role: _selectedRole,
      );
      _emailCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('projects.inviteSuccess', params: {'email': user.email}))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('common.error', params: {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _updateRole(Project project, String userId, Role role) async {
    try {
      await ProjectService.instance.updateMemberRole(
        project: project,
        userId: userId,
        role: role,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('common.error', params: {'error': '$e'}))),
      );
    }
  }

  Future<void> _removeMember(Project project, String userId) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('projects.removeMemberTitle')),
        content: Text(l10n.t('projects.removeMemberMessage')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('confirm.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.t('confirm.delete'))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ProjectService.instance.removeMember(project: project, userId: userId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('common.error', params: {'error': '$e'}))),
      );
    }
  }
}
