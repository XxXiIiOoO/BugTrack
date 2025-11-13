import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/bug.dart';
import '../models/role.dart' show Role, Permission, can;
import '../state/app_state.dart';
import '../widgets/main_drawer.dart';

class EditBugScreen extends StatefulWidget {
  final Bug bug;
  const EditBugScreen({super.key, required this.bug});
  @override
  State<EditBugScreen> createState() => _EditBugScreenState();
}

class _EditBugScreenState extends State<EditBugScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _title;
  late TextEditingController _desc;
  late String _priority;
  late String _status;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.bug.title);
    _desc = TextEditingController(text: widget.bug.description);
    _priority = widget.bug.priority;
    _status = widget.bug.status;
    _deadline = widget.bug.estimatedCompletion;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    final projectId = appState.activeProjectId;
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('home.noProject'))),
      );
      return;
    }
    final role = appState.activeProjectRole ?? Role.tester;
    final currentUserId = appState.currentUser?.id;
    final canEditAny = can(role, Permission.editAnyBug);
    final canEditAssigned =
        can(role, Permission.editAssignedBug) && currentUserId != null && currentUserId == widget.bug.assignedTo;
    if (!canEditAny && !canEditAssigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('home.permissionAction'))),
      );
      return;
    }
    final updated = widget.bug.copyWith(
      title: _title.text.trim(),
      description: _desc.text.trim(),
      priority: _priority,
      status: _status,
      estimatedCompletion: _deadline,
    );
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('bugs')
        .doc(widget.bug.id)
        .update({
      ...updated.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('bug.editTitle'))),
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
              Row(
                children: [
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
                  ElevatedButton(onPressed: _save, child: Text(l10n.t('common.save'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
