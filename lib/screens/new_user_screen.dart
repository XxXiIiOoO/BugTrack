import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/main_drawer.dart';
import '../widgets/user_form.dart';

class NewUserScreen extends StatelessWidget {
  const NewUserScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('admin.addUser'))),
      drawer: const MainDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: UserForm(
          onSubmit: (data) async {
            final doc = FirebaseFirestore.instance.collection('users').doc();
            await doc.set({
              'email': data['email'],
              'displayName': data['displayName'],
              'firstName': data['firstName'],
              'lastName': data['lastName'],
              'role': data['role'],
              'photoUrl': '',
              'projects': <String>[],
              'createdAt': FieldValue.serverTimestamp(),
              'lastSeenAt': FieldValue.serverTimestamp(),
            });
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
