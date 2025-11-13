import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/role_labels.dart';
import '../models/UserData.dart';
import '../service/storage_service.dart';
import '../state/app_state.dart';
import '../widgets/main_drawer.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _storage = StorageService();
  final _picker = ImagePicker();
  bool _uploading = false;
  Future<_UserStats>? _statsFuture;
  String _statsKey = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appState = context.watch<AppState>();
    final authUser = FirebaseAuth.instance.currentUser;
    final userData = appState.currentUser;

    if (userData == null || authUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('profile.title'))),
        drawer: const MainDrawer(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final statsFuture = _ensureStats(appState);
    final theme = Theme.of(context);
    final avatarUrl = userData.photoUrl.isNotEmpty
        ? userData.photoUrl
        : (authUser.photoURL ?? '');
    final localeName = l10n.locale.toLanguageTag();
    final dateFormatter = DateFormat.yMMMMd(localeName);
    final createdAtText = userData.createdAt != null ? dateFormatter.format(userData.createdAt!) : '—';
    final lastSeenText = userData.lastSeenAt != null ? dateFormatter.format(userData.lastSeenAt!) : '—';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('profile.title'))),
      drawer: const MainDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userData.displayName.isEmpty ? l10n.t('admin.noName') : userData.displayName,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userData.email,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.workspace_premium_outlined, size: 18),
                                  label: Text(roleLabel(l10n, userData.role)),
                                ),
                                Chip(
                                  avatar: const Icon(Icons.calendar_month, size: 18),
                                  label: Text('${l10n.t('profile.memberSince')}: $createdAtText'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _uploading ? null : () => _changeAvatar(l10n, appState, authUser),
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_outlined),
                      label: Text(l10n.t('profile.changeAvatar')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    l10n.t('profile.infoTitle'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(l10n.t('profile.name')),
                  subtitle: Text(
                    userData.displayName.isEmpty
                        ? '${userData.firstName} ${userData.lastName}'.trim().isEmpty
                            ? l10n.t('admin.noName')
                            : '${userData.firstName} ${userData.lastName}'.trim()
                        : userData.displayName,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(l10n.t('profile.email')),
                  subtitle: Text(userData.email),
                ),
                ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: Text(l10n.t('profile.uid')),
                  subtitle: SelectableText(authUser.uid),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(l10n.t('profile.memberSince')),
                  subtitle: Text(createdAtText),
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(l10n.t('profile.lastSeen')),
                  subtitle: Text(lastSeenText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('profile.statsTitle'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<_UserStats>(
                    future: statsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text(
                          l10n.t('common.error', params: {'error': '${snapshot.error}'}),
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                        );
                      }
                      final stats = snapshot.data ?? const _UserStats();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatTile(
                            label: l10n.t('profile.tasksCreated'),
                            value: stats.created,
                          ),
                          _StatTile(
                            label: l10n.t('profile.tasksClosed'),
                            value: stats.closed,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _signOut(),
            icon: const Icon(Icons.logout),
            label: Text(l10n.t('profile.signOut')),
          ),
        ],
      ),
    );
  }

  Future<void> _changeAvatar(
    AppLocalizations l10n,
    AppState appState,
    User authUser,
  ) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _uploading = true);
      late final String url;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        url = await _storage.uploadUserAvatarBytes(
          uid: authUser.uid,
          bytes: bytes,
          fileName: picked.name,
        );
      } else {
        url = await _storage.uploadUserAvatarFile(
          uid: authUser.uid,
          filePath: picked.path,
        );
      }
      await FirebaseFirestore.instance.collection('users').doc(authUser.uid).update({
        'photoUrl': url,
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
      await authUser.updatePhotoURL(url);
      final current = appState.currentUser;
      if (current != null) {
        appState.setCurrentUser(current.copyWith(photoUrl: url));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('profile.avatarUpdated'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('profile.avatarError', params: {'error': '$e'}))),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/');
  }

  Future<_UserStats> _ensureStats(AppState appState) {
    final uid = appState.currentUser?.id ?? '';
    final projectIds = appState.projects.map((p) => p.id).join(',');
    final key = '$uid|$projectIds';
    if (_statsFuture == null || _statsKey != key) {
      _statsKey = key;
      _statsFuture = _loadStats(appState);
    }
    return _statsFuture!;
  }

  Future<_UserStats> _loadStats(AppState appState) async {
    final uid = appState.currentUser?.id;
    if (uid == null || appState.projects.isEmpty) {
      return const _UserStats();
    }
    final futures = appState.projects.map((project) async {
      final bugsRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(project.id)
          .collection('bugs');
      final createdSnap = await bugsRef.where('createdBy', isEqualTo: uid).get();
      final closedSnap = await bugsRef
          .where('assignedTo', isEqualTo: uid)
          .where('status', isEqualTo: 'Done')
          .get();
      return _UserStats(created: createdSnap.size, closed: closedSnap.size);
    });
    final partial = await Future.wait(futures);
    var created = 0;
    var closed = 0;
    for (final stats in partial) {
      created += stats.created;
      closed += stats.closed;
    }
    return _UserStats(created: created, closed: closed);
  }
}

class _UserStats {
  final int created;
  final int closed;
  const _UserStats({this.created = 0, this.closed = 0});
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
