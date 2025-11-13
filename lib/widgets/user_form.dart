import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/role_labels.dart';
import '../models/role.dart';

class UserForm extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final void Function(Map<String, dynamic> data) onSubmit;
  const UserForm({super.key, this.initial, required this.onSubmit});

  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _email;
  String _role = Role.tester.name;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? const <String, dynamic>{};
    final initialFirst = initial['firstName'] as String? ?? '';
    final initialLast = initial['lastName'] as String? ?? '';
    final initialDisplay = initial['displayName'] as String? ?? '';

    String deriveFirst = initialFirst;
    String deriveLast = initialLast;
    if (deriveFirst.isEmpty && deriveLast.isEmpty && initialDisplay.isNotEmpty) {
      final parts = initialDisplay.split(' ');
      deriveFirst = parts.isNotEmpty ? parts.first : '';
      deriveLast = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    _first = TextEditingController(text: deriveFirst);
    _last = TextEditingController(text: deriveLast);
    _email = TextEditingController(text: initial['email'] as String? ?? '');

    final initialRole = initial['role'] as String?;
    final knownRoles = Role.values.map((r) => r.name).toSet();
    _role = initialRole != null && knownRoles.contains(initialRole) ? initialRole : Role.tester.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _first,
            decoration: InputDecoration(labelText: l10n.t('register.firstName')),
            validator: (v) => (v == null || v.isEmpty) ? l10n.t('validation.required') : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _last,
            decoration: InputDecoration(labelText: l10n.t('register.lastName')),
            validator: (v) => (v == null || v.isEmpty) ? l10n.t('validation.required') : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            decoration: InputDecoration(labelText: l10n.t('login.email')),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty) ? l10n.t('validation.email') : null,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _role,
            decoration: InputDecoration(labelText: l10n.t('admin.role')),
            items: [
              for (final role in Role.values)
                DropdownMenuItem(value: role.name, child: Text(roleLabel(l10n, role))),
            ],
            onChanged: (v) => setState(() => _role = v ?? Role.tester.name),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              final email = _email.text.trim().toLowerCase();
              widget.onSubmit({
                'firstName': _first.text.trim(),
                'lastName': _last.text.trim(),
                'email': email,
                'displayName': _buildDisplayName(),
                'role': _role,
              });
            },
            child: Text(l10n.t('common.save')),
          )
        ],
      ),
    );
  }
}

extension on _UserFormState {
  String _buildDisplayName() {
    final parts = <String>[
      _first.text.trim(),
      _last.text.trim(),
    ]..removeWhere((element) => element.isEmpty);
    return parts.isEmpty ? _email.text.trim() : parts.join(' ');
  }
}
