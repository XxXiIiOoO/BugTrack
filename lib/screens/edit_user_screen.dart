import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/main_drawer.dart';
import '../widgets/user_form.dart';

class EditUserScreen extends StatelessWidget {
  final String uid;
  const EditUserScreen({super.key, required this.uid});

  Future<Map<String, dynamic>> _load() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data() as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('admin.editUserTitle'))),
      drawer: const MainDrawer(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: UserForm(
              initial: snap.data!,
              onSubmit: (data) async {
                await FirebaseFirestore.instance.collection('users').doc(uid).update(data);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          );
        },
      ),
    );
  }
}
