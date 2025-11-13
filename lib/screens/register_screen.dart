import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

import '../models/role.dart';
import '../widgets/main_drawer.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  bool _loading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final l10n = context.l10n;
    try {
      final email = _email.text.trim().toLowerCase();
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _password.text.trim(),
      );
      final uid = cred.user!.uid;
      final displayName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'displayName': displayName.isEmpty ? _email.text.trim() : displayName,
        'role': Role.tester.name,
        'projects': <String>[],
        'photoUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('register.success'))),
      );
      context.go('/');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? l10n.t('register.error'))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('register.title'))),
      drawer: const MainDrawer(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _firstName,
                      decoration: InputDecoration(labelText: l10n.t('register.firstName')),
                      validator: (v) => (v == null || v.isEmpty) ? l10n.t('validation.required') : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _lastName,
                      decoration: InputDecoration(labelText: l10n.t('register.lastName')),
                      validator: (v) => (v == null || v.isEmpty) ? l10n.t('validation.required') : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _email,
                      decoration: InputDecoration(labelText: l10n.t('login.email')),
                      validator: (v) => (v == null || v.isEmpty) ? l10n.t('validation.email') : null,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _password,
                      decoration: InputDecoration(labelText: l10n.t('login.password')),
                      validator: (v) => (v == null || v.length < 6) ? l10n.t('validation.passwordMin') : null,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    _loading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(onPressed: _register, child: Text(l10n.t('register.signUp'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
