import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../widgets/main_drawer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _sendingReset = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final l10n = context.l10n;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      if (!mounted) return;
      context.go('/home');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? l10n.t('login.error'))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setResetLoading(bool value) {
    if (!mounted) return;
    setState(() => _sendingReset = value);
  }

  Future<void> _resetPassword() async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: _email.text.trim());
    final localFormKey = GlobalKey<FormState>();
    var dialogLoading = false;

    Future<void> sendReset(StateSetter setStateDialog) async {
      if (!localFormKey.currentState!.validate()) return;
      setStateDialog(() => dialogLoading = true);
      _setResetLoading(true);
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: controller.text.trim());
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? l10n.t('login.resetError'))),
        );
      } finally {
        setStateDialog(() => dialogLoading = false);
        _setResetLoading(false);
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(l10n.t('login.resetTitle')),
              content: Form(
                key: localFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.t('login.resetDescription')),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller,
                      decoration: InputDecoration(labelText: l10n.t('login.email')),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || v.isEmpty) ? l10n.t('validation.email') : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.t('common.cancel')),
                ),
                ElevatedButton(
                  onPressed: dialogLoading ? null : () => sendReset(setStateDialog),
                  child: dialogLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.t('login.resetSend')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('login.resetSent'))),
      );
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('login.title'))),
      drawer: const MainDrawer(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _email,
                    decoration: InputDecoration(labelText: l10n.t('login.email')),
                    validator: (v) => (v == null || v.isEmpty) ? l10n.t('validation.email') : null,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(labelText: l10n.t('login.password')),
                    validator: (v) => (v == null || v.length < 6) ? l10n.t('validation.passwordMin') : null,
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(onPressed: _login, child: Text(l10n.t('login.signIn'))),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _sendingReset ? null : _resetPassword,
                    child: Text(l10n.t('login.forgotPassword')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text(l10n.t('login.createAccount')),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
