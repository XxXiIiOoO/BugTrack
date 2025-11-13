import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/bug.dart';
import '../models/role.dart' show Role, Permission, can;
import '../state/app_state.dart';
import '../service/email_notification_service.dart';
import '../widgets/main_drawer.dart';

class NewBugScreen extends StatefulWidget {
  const NewBugScreen({super.key});

  @override
  State<NewBugScreen> createState() => _NewBugScreenState();
}

class _NewBugScreenState extends State<NewBugScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _labels = <String>[];
  String _priority = 'Medium';
  String _status = 'Open';
  DateTime? _deadline;
  bool _assignToMe = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    final l10n = context.l10n;
    final projectId = appState.activeProjectId;
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('home.noProject'))),
      );
      return;
    }
    final currentUser = appState.currentUser;
    final role = appState.activeProjectRole ?? Role.tester;
    final canAssignToSelf = currentUser != null &&
        (role == Role.admin || role == Role.developer || can(role, Permission.changeStatusAssigned));
    final assignedTo = _assignToMe && canAssignToSelf ? currentUser!.id : '';
    final createdAt = DateTime.now();
    final bug = Bug(
      id: '',
      title: _title.text.trim(),
      description: _desc.text.trim(),
      priority: _priority,
      status: _status,
      labels: List.unmodifiable(_labels),
      creationDate: createdAt,
      estimatedCompletion: _deadline,
      assignedTo: assignedTo,
      createdBy: currentUser?.id ?? '',
    );
    final bugRef = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('bugs')
        .add({
      ...bug.toMap(),
      'updatedAt': Timestamp.fromDate(createdAt),
    });
    if (assignedTo.isNotEmpty) {
      final projectName = appState.activeProject?.name ?? l10n.t('projects.untitled');
      final creatorName = (currentUser?.displayName.isNotEmpty == true
              ? currentUser!.displayName
              : currentUser?.email) ??
          'BugTreck';
      unawaited(
        EmailNotificationService.instance.sendNewTaskEmail(
          recipientUserId: assignedTo,
          projectId: projectId,
          bugId: bugRef.id,
          bugTitle: _title.text.trim(),
          projectName: projectName,
          creatorName: creatorName,
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('newBug.created'))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentUser = appState.currentUser;
    final role = appState.activeProjectRole ?? Role.tester;
    final canAssignToSelf = currentUser != null &&
        (role == Role.admin || role == Role.developer || can(role, Permission.changeStatusAssigned));
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('newBug.title'))),
      drawer: const MainDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _title,
                decoration: InputDecoration(labelText: l10n.t('newBug.summary')),
                validator: (v) => (v == null || v.isEmpty) ? l10n.t('validation.required') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _desc,
                decoration: InputDecoration(labelText: l10n.t('newBug.description')),
                maxLines: 4,
                validator: (v) => (v == null || v.isEmpty) ? l10n.t('validation.required') : null,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _priority,
                  items: [
                    DropdownMenuItem(value: 'Low', child: Text(l10n.t('newBug.priority.low'))),
                    DropdownMenuItem(value: 'Medium', child: Text(l10n.t('newBug.priority.medium'))),
                    DropdownMenuItem(value: 'High', child: Text(l10n.t('newBug.priority.high'))),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'Medium'),
                  decoration: InputDecoration(labelText: l10n.t('newBug.priority')),
                )),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _status,
                  items: [
                    DropdownMenuItem(value: 'Open', child: Text(l10n.t('status.open'))),
                    DropdownMenuItem(value: 'In Progress', child: Text(l10n.t('status.inProgress'))),
                    DropdownMenuItem(value: 'Done', child: Text(l10n.t('status.done'))),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'Open'),
                  decoration: InputDecoration(labelText: l10n.t('newBug.status')),
                )),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _labelCtrl,
                decoration: InputDecoration(
                  labelText: l10n.t('newBug.label'),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: l10n.t('newBug.addLabel'),
                    onPressed: _addLabel,
                  ),
                ),
                onSubmitted: (_) => _addLabel(),
              ),
              if (_labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in _labels)
                      InputChip(
                        label: Text(label),
                        onDeleted: () => setState(() => _labels.remove(label)),
                      ),
                  ],
                ),
              ],
              if (canAssignToSelf)
                SwitchListTile(
                  value: _assignToMe,
                  onChanged: (v) => setState(() => _assignToMe = v),
                  title: Text(currentUser?.displayName.isNotEmpty == true
                      ? '${l10n.t('newBug.assignToMe')} (${currentUser!.displayName})'
                      : l10n.t('newBug.assignToMe')),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _deadline ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 5),
                    );
                    if (picked != null) setState(() => _deadline = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(_deadline == null
                      ? l10n.t('newBug.deadline')
                      : _deadline!.toString().split(' ').first),
                )),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _save, child: Text(l10n.t('newBug.save'))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _addLabel() {
    final text = _labelCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_labels.contains(text)) {
        _labels.add(text);
      }
      _labelCtrl.clear();
    });
  }
}
