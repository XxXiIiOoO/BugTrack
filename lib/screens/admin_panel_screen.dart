// lib/screens/admin_panel_screen.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../l10n/app_localizations.dart';
import '../l10n/role_labels.dart';
import '../models/UserData.dart';
import '../models/role.dart';
import '../widgets/main_drawer.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  String _search = '';
  Role? _roleFilter;
  final Set<String> _selectedUserIds = <String>{};
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayName');
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('admin.title')),
        actions: [
          IconButton(
            tooltip: l10n.t('admin.addUser'),
            onPressed: () => context.push('/admin/users/new'),
            icon: const Icon(Icons.person_add_alt_1),
          )
        ],
      ),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.t('admin.searchHint'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Center(child: Text(l10n.t('admin.empty')));
                }

                final users = snap.data!.docs.map((d) {
                  final data = d.data();
                  return UserData.fromMap(d.id, data);
                }).where((u) {
                  if (_search.isEmpty) return true;
                  final hay = '${u.displayName} ${u.email}'.toLowerCase();
                  return hay.contains(_search);
                }).toList();

                List<UserData> filteredUsers = users;
                if (_roleFilter != null) {
                  filteredUsers = filteredUsers.where((u) => u.role == _roleFilter).toList();
                }

                final visibleIds = filteredUsers.map((u) => u.id).toSet();
                final toRemove = _selectedUserIds.where((id) => !visibleIds.contains(id)).toList();
                if (toRemove.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _selectedUserIds.removeAll(toRemove);
                    });
                  });
                }

                if (filteredUsers.isEmpty) {
                  return Center(child: Text(l10n.t('admin.noResults')));
                }

                return Column(
                  children: [
                    _buildToolbar(l10n, filteredUsers),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: DataTable(
                          showCheckboxColumn: true,
                          columns: [
                            DataColumn(label: Text(l10n.t('admin.name'))),
                            DataColumn(label: Text(l10n.t('admin.email'))),
                            DataColumn(label: Text(l10n.t('admin.role'))),
                            DataColumn(label: Text(l10n.t('admin.projects'))),
                            DataColumn(label: Text(l10n.t('admin.uid'))),
                            DataColumn(label: Text(l10n.t('admin.actions'))),
                          ],
                          rows: filteredUsers.map((u) => _userRow(context, u, l10n)).toList(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(AppLocalizations l10n, List<UserData> users) {
    final hasSelection = _selectedUserIds.isNotEmpty;
    final infoText = hasSelection
        ? l10n.t('admin.toolbar.selected', params: {'count': '${_selectedUserIds.length}'})
        : l10n.t('admin.toolbar.total', params: {'count': '${users.length}'});

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.t('admin.filterAll')),
                selected: _roleFilter == null,
                onSelected: (_) => setState(() => _roleFilter = null),
              ),
              for (final role in Role.values)
                ChoiceChip(
                  label: Text(roleLabel(l10n, role)),
                  selected: _roleFilter == role,
                  onSelected: (selected) {
                    setState(() => _roleFilter = selected ? role : null);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(infoText),
              if (hasSelection)
                FilledButton.icon(
                  icon: const Icon(Icons.security),
                  label: Text(l10n.t('admin.bulkRole')),
                  onPressed: _bulkChangeRole,
                ),
              if (hasSelection)
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.t('admin.bulkDelete')),
                  onPressed: _bulkDeleteUsers,
                ),
              if (hasSelection)
                TextButton.icon(
                  icon: const Icon(Icons.clear),
                  label: Text(l10n.t('admin.clearSelection')),
                  onPressed: () => setState(() => _selectedUserIds.clear()),
                ),
              if (!hasSelection)
                FilledButton.icon(
                  icon: const Icon(Icons.file_download),
                  label: Text(l10n.t('admin.export')),
                  onPressed: _exporting ? null : () => _exportUsers(users),
                ),
            ],
          ),
        ],
      ),
    );
  }

  DataRow _userRow(BuildContext context, UserData u, AppLocalizations l10n) {
    final projectsCount = u.projects.length;
    final selected = _selectedUserIds.contains(u.id);

    return DataRow(
      selected: selected,
      onSelectChanged: (value) {
        setState(() {
          if (value ?? false) {
            _selectedUserIds.add(u.id);
          } else {
            _selectedUserIds.remove(u.id);
          }
        });
      },
      cells: [
        DataCell(Text(u.displayName.isEmpty ? l10n.t('admin.noName') : u.displayName)),
        DataCell(Text(u.email)),
        DataCell(_RoleDropdown(
          value: u.role,
          l10n: l10n,
          onChanged: (r) => _updateRole(u.id, r),
        )),
        DataCell(Text('$projectsCount')),
        DataCell(SelectableText(u.id, maxLines: 1)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.t('admin.edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/admin/users/${u.id}/edit'),
            ),
            IconButton(
              tooltip: l10n.t('admin.contact'),
              icon: const Icon(Icons.email_outlined),
              onPressed: () => _contactUser(u),
            ),
            IconButton(
              tooltip: l10n.t('admin.resetPassword'),
              icon: const Icon(Icons.lock_reset),
              onPressed: () => _resetPassword(u.email, l10n),
            ),
            IconButton(
              tooltip: l10n.t('admin.delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteUserDoc(u.id, l10n),
            ),
          ],
        )),
      ],
    );
  }

  Future<void> _updateRole(String userId, Role newRole) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': newRole.name,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t(
              'admin.roleUpdated',
              params: {'role': roleLabel(context.l10n, newRole)},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _resetPassword(String email, AppLocalizations l10n) async {
    // Здесь только UI-индикатор. Сброс пароля делает FirebaseAuth.instance.sendPasswordResetEmail(email: email)
    // В админке без явной авторизации/прав лучше просто подсказать.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('admin.passwordHint', params: {'email': email}))),
    );
  }

  Future<void> _bulkChangeRole() async {
    if (_selectedUserIds.isEmpty) {
      _showSelectionRequired();
      return;
    }
    final l10n = context.l10n;
    final role = await showDialog<Role>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.t('admin.bulkRoleTitle', params: {'count': '${_selectedUserIds.length}'})),
        children: [
          for (final r in Role.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(roleLabel(l10n, r)),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('confirm.cancel')),
          ),
        ],
      ),
    );
    if (role == null) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selectedUserIds) {
      batch.update(FirebaseFirestore.instance.collection('users').doc(id), {'role': role.name});
    }
    await batch.commit();
    if (!mounted) return;
    setState(() => _selectedUserIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.t('admin.roleUpdated', params: {'role': roleLabel(l10n, role)}),
        ),
      ),
    );
  }

  Future<void> _bulkDeleteUsers() async {
    if (_selectedUserIds.isEmpty) {
      _showSelectionRequired();
      return;
    }
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('admin.bulkDeleteTitle', params: {'count': '${_selectedUserIds.length}'})),
        content: Text(l10n.t('admin.bulkDeleteMsg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('confirm.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.t('confirm.delete'))),
        ],
      ),
    );
    if (confirmed != true) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selectedUserIds) {
      batch.delete(FirebaseFirestore.instance.collection('users').doc(id));
    }
    await batch.commit();
    if (!mounted) return;
    setState(() => _selectedUserIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('admin.userDeleted'))),
    );
  }

  Future<void> _exportUsers(List<UserData> users) async {
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('admin.exportEmpty'))),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final rows = <List<dynamic>>[
        ['Display Name', 'Email', 'Role', 'Projects', 'UID'],
        ...users.map((u) => [
              u.displayName,
              u.email,
              roleLabel(context.l10n, u.role),
              u.projects.length,
              u.id,
            ]),
      ];
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/users_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: context.l10n.t('admin.exportShareText'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('admin.exportReady'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('admin.exportError', params: {'error': '$e'}))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _deleteUserDoc(String userId, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('confirm.deleteUserTitle')),
        content: Text(l10n.t('confirm.deleteUserMsg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('confirm.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.t('confirm.delete'))),
        ],
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('admin.userDeleted'))),
      );
    }
  }

  Future<void> _contactUser(UserData user) async {
    final subject = Uri.encodeComponent('BugTreck');
    final mailto = 'mailto:${user.email}?subject=$subject';
    final canLaunch = await canLaunchUrlString(mailto);
    if (!canLaunch) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('admin.contactError'))),
      );
      return;
    }
    await launchUrlString(mailto);
  }

  void _showSelectionRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('admin.bulkNoSelection'))),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  final Role value;
  final ValueChanged<Role> onChanged;
  final AppLocalizations l10n;

  const _RoleDropdown({required this.value, required this.onChanged, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<Role>(
      value: value,
      onChanged: (r) => r != null ? onChanged(r) : null,
      items: Role.values
          .map(
            (r) => DropdownMenuItem<Role>(
              value: r,
              child: Text(roleLabel(l10n, r)),
            ),
          )
          .toList(),
    );
  }
}
