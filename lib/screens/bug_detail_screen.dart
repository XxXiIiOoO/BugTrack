import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../l10n/app_localizations.dart';
import '../models/ChatMessage.dart';
import '../models/UserData.dart';
import '../models/bug.dart';
import '../models/role.dart' show Role, Permission, can;
import '../service/user_cache.dart';
import '../state/app_state.dart';
import '../widgets/main_drawer.dart';
import 'edit_bug_screen.dart';

class BugDetailScreen extends StatefulWidget {
  final String bugId;
  final String? projectId;
  const BugDetailScreen({super.key, required this.bugId, this.projectId});

  @override
  State<BugDetailScreen> createState() => _BugDetailScreenState();
}

class _BugDetailScreenState extends State<BugDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  final _pendingAttachments = <_PendingAttachment>[];
  bool _sendingMessage = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;
      final files = result.files.where((f) => (f.path ?? '').isNotEmpty);
      if (files.isEmpty) return;
      if (!mounted) return;
      setState(() {
        for (final file in files) {
          final path = file.path;
          if (path == null) continue;
          _pendingAttachments.add(
            _PendingAttachment(
              name: file.name,
              path: path,
              contentType: _guessContentType(file.name),
            ),
          );
        }
      });
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    try {
      final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
      final picked = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      if (!mounted) return;
      setState(() {
        _pendingAttachments.add(
          _PendingAttachment(
            name: picked.name,
            path: picked.path,
            contentType: _guessContentType(picked.name, fallback: 'image/jpeg'),
          ),
        );
      });
    } catch (e) {
      _showError(e);
    }
  }

  String _guessContentType(String name, {String fallback = 'application/octet-stream'}) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appState = context.watch<AppState>();
    final userData = appState.currentUser;
    final projectId = widget.projectId ?? appState.activeProjectId;

    // ВАЖНО: сначала проверяем, что projectId не null
    if (projectId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('bug.detailTitle'))),
        drawer: const MainDrawer(),
        body: Center(child: Text(l10n.t('home.noProject'))),
      );
    }

    // Здесь projectId гарантированно не null
    final role = appState.roleForProject(projectId) ?? Role.tester;
    final canComment = can(role, Permission.comment);
    final currentUserId = userData?.id;

    return FutureBuilder<Bug>(
      future: _loadBug(projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.t('bug.detailTitle'))),
            drawer: const MainDrawer(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.t('bug.detailTitle'))),
            drawer: const MainDrawer(),
            body: Center(child: Text(l10n.t('home.noData'))),
          );
        }

        final bug = snapshot.data!;
        final canEdit = _canEditBug(role, bug, currentUserId);
        final canDelete = role == Role.admin;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.t('bug.detailTitle')),
            actions: [
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.t('home.actions.edit'),
                  onPressed: () => _editBug(bug),
                ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.t('home.actions.delete'),
                  onPressed: () => _deleteBug(projectId, bug),
                ),
            ],
          ),
          drawer: const MainDrawer(),
          body: Column(
            children: [
              _buildHeader(context, bug, l10n),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _watchComments(projectId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data ?? const <ChatMessage>[];
                    if (messages.isEmpty) {
                      return Center(child: Text(l10n.t('bug.noComments')));
                    }
                    return ListView.separated(
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final author = message.authorName.isEmpty
                            ? l10n.t('admin.noName')
                            : message.authorName;
                        final time = TimeOfDay.fromDateTime(message.timestamp).format(context);
                        return ListTile(
                          title: Text(author),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.text.isNotEmpty)
                                Text(message.text),
                              if (message.attachments.isNotEmpty) ...[
                                if (message.text.isNotEmpty) const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final att in message.attachments)
                                      _MessageAttachment(
                                        attachment: att,
                                        onTap: () => _openAttachment(att.url),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Text(time),
                        );
                      },
                    );
                  },
                ),
              ),
              _buildMessageComposer(projectId, canComment, userData, l10n),
            ],
          ),
        );
      },
    );
  }

  Future<Bug> _loadBug(String projectId) async {
    final doc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('bugs')
        .doc(widget.bugId)
        .get();
    return Bug.fromDoc(doc);
  }

  Widget _buildHeader(BuildContext context, Bug bug, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final localeTag = l10n.locale.toLanguageTag();
    final dateFmt = DateFormat.yMMMMd(localeTag);
    final creationText = dateFmt.format(bug.creationDate);
    final dueText = bug.estimatedCompletion != null ? dateFmt.format(bug.estimatedCompletion!) : '—';
    final isOverdue = bug.estimatedCompletion != null &&
        bug.estimatedCompletion!.isBefore(DateTime.now()) &&
        bug.status.toLowerCase() != 'done';
    final statusLabel = _statusLabel(l10n, bug.status);
    final priorityLabel = _priorityLabel(l10n, bug.priority);
    final userCache = UserCache.instance;

    final assigneeFuture = bug.assignedTo.isEmpty
        ? Future.value(l10n.t('home.unassigned'))
        : userCache.getName(bug.assignedTo);
    final createdFuture = bug.createdBy.isEmpty
        ? Future.value(l10n.t('bug.unknownAuthor'))
        : userCache.getName(bug.createdBy);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bug.title.isEmpty ? l10n.t('bug.untitled') : bug.title,
              style: theme.textTheme.titleLarge,
            ),
            if (bug.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(bug.description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.info_outline, size: 18),
                  label: Text('${l10n.t('bug.statusLabel')}: $statusLabel'),
                ),
                Chip(
                  avatar: const Icon(Icons.flag_outlined, size: 18),
                  label: Text('${l10n.t('bug.priorityLabel')}: $priorityLabel'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.person_outline,
              title: l10n.t('bug.assignedTo'),
              child: FutureBuilder<String>(
                future: assigneeFuture,
                builder: (context, snapshot) {
                  final value = snapshot.data ?? l10n.t('home.unassigned');
                  return Text(value);
                },
              ),
            ),
            _InfoTile(
              icon: Icons.person,
              title: l10n.t('bug.createdBy'),
              child: FutureBuilder<String>(
                future: createdFuture,
                builder: (context, snapshot) {
                  final value = snapshot.data ?? l10n.t('bug.unknownAuthor');
                  return Text(value);
                },
              ),
            ),
            _InfoTile(
              icon: Icons.calendar_month,
              title: l10n.t('bug.createdAt'),
              child: Text(creationText),
            ),
            _InfoTile(
              icon: Icons.event,
              title: l10n.t('bug.dueDate'),
              child: Text(
                dueText,
                style: isOverdue
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      )
                    : theme.textTheme.bodyMedium,
              ),
            ),
            _InfoTile(
              icon: Icons.label_outline,
              title: l10n.t('bug.labels'),
              child: bug.labels.isEmpty
                  ? Text(l10n.t('bug.noLabels'))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final label in bug.labels) Chip(label: Text(label)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer(
    String projectId,
    bool canComment,
    UserData? userData,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingAttachments.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final att in _pendingAttachments)
                    InputChip(
                      label: Text(
                        att.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: canComment
                          ? () {
                              setState(() => _pendingAttachments.remove(att));
                            }
                          : null,
                    ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: l10n.t('chat.attachFile'),
                icon: const Icon(Icons.attach_file),
                onPressed: canComment ? _pickFiles : null,
              ),
              IconButton(
                tooltip: l10n.t('chat.attachImage'),
                icon: const Icon(Icons.photo_library_outlined),
                onPressed: canComment ? () => _pickImage(fromCamera: false) : null,
              ),
              IconButton(
                tooltip: l10n.t('chat.attachCamera'),
                icon: const Icon(Icons.photo_camera_outlined),
                onPressed: canComment ? () => _pickImage(fromCamera: true) : null,
              ),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  enabled: canComment && !_sendingMessage,
                  decoration: InputDecoration(
                    hintText: l10n.t('bug.messageHint'),
                    suffixIcon: !canComment ? const Icon(Icons.lock_outline, size: 18) : null,
                  ),
                  onSubmitted: (_) => _sendMessage(projectId, canComment, userData, l10n),
                ),
              ),
              const SizedBox(width: 8),
              _sendingMessage
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: canComment
                          ? () => _sendMessage(projectId, canComment, userData, l10n)
                          : null,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Stream<List<ChatMessage>> _watchComments(String projectId) {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('bugs')
        .doc(widget.bugId)
        .collection('comments')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
  }

  bool _canEditBug(Role role, Bug bug, String? currentUserId) {
    if (can(role, Permission.editAnyBug)) return true;
    if (currentUserId == null) return false;
    return can(role, Permission.editAssignedBug) && bug.assignedTo == currentUserId;
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return l10n.t('status.open');
      case 'in progress':
        return l10n.t('status.inProgress');
      case 'done':
        return l10n.t('status.done');
      default:
        return status;
    }
  }

  String _priorityLabel(AppLocalizations l10n, String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return l10n.t('newBug.priority.low');
      case 'medium':
        return l10n.t('newBug.priority.medium');
      case 'high':
        return l10n.t('newBug.priority.high');
      default:
        return priority;
    }
  }

  Future<void> _editBug(Bug bug) async {
    final updated = await Navigator.of(context).push<Bug>(
      MaterialPageRoute(builder: (_) => EditBugScreen(bug: bug)),
    );
    if (updated != null && mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteBug(String projectId, Bug bug) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('confirm.deleteBugTitle')),
        content: Text(l10n.t('confirm.deleteBugMsg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('confirm.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.t('confirm.delete'))),
        ],
      ),
    );
    if (confirmed != true) return;

    final firestore = FirebaseFirestore.instance;
    final bugRef = firestore
        .collection('projects')
        .doc(projectId)
        .collection('bugs')
        .doc(widget.bugId);
    final commentsSnap = await bugRef.collection('comments').get();
    final batch = firestore.batch();
    batch.delete(bugRef);
    for (final doc in commentsSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('home.taskDeleted'))),
    );
  }

  Future<void> _sendMessage(
      String projectId,
      bool canComment,
      UserData? userData,
      AppLocalizations l10n,
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _msgCtrl.text.trim();
    if (user == null) return;
    if (text.isEmpty && _pendingAttachments.isEmpty) return;
    if (!canComment) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('home.permissionAction'))),
      );
      return;
    }
    if (_sendingMessage) return;
    final authorName = (userData?.displayName.isNotEmpty ?? false)
        ? userData!.displayName
        : (user.email ?? userData?.email ?? l10n.t('admin.noName'));
    setState(() => _sendingMessage = true);
    try {
      final attachments = await _uploadAttachments(projectId);
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('bugs')
          .doc(widget.bugId)
          .collection('comments')
          .add({
        'text': text,
        'authorId': user.uid,
        'authorName': authorName,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'attachments': attachments.map((a) => a.toMap()).toList(),
      });
      _msgCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('common.error', params: {'error': '$e'}))),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingMessage = false);
      } else {
        _sendingMessage = false;
      }
    }
  }

  Future<List<ChatAttachment>> _uploadAttachments(String projectId) async {
    if (_pendingAttachments.isEmpty) return const [];
    final storage = FirebaseStorage.instance;
    final uploads = <ChatAttachment>[];
    for (final attachment in List<_PendingAttachment>.from(_pendingAttachments)) {
      final file = File(attachment.path);
      if (!await file.exists()) continue;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${attachment.name.replaceAll(' ', '_')}';
      final ref = storage
          .ref('projects/$projectId/bugs/${widget.bugId}/comments/$fileName');
      final metadata = SettableMetadata(contentType: attachment.contentType);
      await ref.putFile(file, metadata);
      final url = await ref.getDownloadURL();
      uploads.add(ChatAttachment(
        name: attachment.name,
        url: url,
        contentType: attachment.contentType,
      ));
    }
    if (mounted) {
      setState(() => _pendingAttachments.clear());
    } else {
      _pendingAttachments.clear();
    }
    return uploads;
  }

  Future<void> _openAttachment(String url) async {
    final success = await launchUrlString(url);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('chat.openFailed'))),
      );
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('common.error', params: {'error': '$error'}))),
    );
  }
}

class _PendingAttachment {
  final String name;
  final String path;
  final String contentType;

  const _PendingAttachment({
    required this.name,
    required this.path,
    required this.contentType,
  });
}

class _MessageAttachment extends StatelessWidget {
  const _MessageAttachment({
    required this.attachment,
    required this.onTap,
  });

  final ChatAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            attachment.url,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 120,
              height: 120,
              color: Colors.grey.shade300,
              child: const Icon(Icons.image_not_supported),
            ),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.attach_file),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          attachment.name,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                DefaultTextStyle(
                  style: theme.textTheme.bodyMedium ?? const TextStyle(),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
