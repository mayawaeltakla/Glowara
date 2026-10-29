/// شاشات الدخول والتسجيل — حساب محلي على الجهاز.
library glowara.feature.auth;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

String? authErrorText(BuildContext context, String? code) {
  switch (code) {
    case 'invalid_email':
      return context.tr('invalidEmail');
    case 'weak_password':
      return context.tr('weakPassword');
    case 'email_exists':
      return context.tr('emailExists');
    case 'account_not_found':
      return context.tr('accountNotFound');
    case 'wrong_password':
      return context.tr('wrongPassword');
    case 'login_failed':
    default:
      return context.tr('loginFailed');
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: c.heroGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, 12)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'G',
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.welcome,
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.welcomeSub,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: c.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => context.go('/signup'),
                    child: Text(l10n.getStarted),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () => context.go('/login'),
                    child: Text(l10n.login),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr('accountLocalNote'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => showAboutDialog(
                    context: context,
                    applicationName: l10n.appTitle,
                    applicationVersion: '1.0.0',
                  ),
                  child: Text(l10n.about),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = AppState.of(context);
    final result = await state.login(email: _email.text.trim(), password: _password.text);
    if (!mounted) return;
    if (result.ok) {
      context.go('/');
    } else {
      setState(() {
        _busy = false;
        _error = authErrorText(context, result.error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(backgroundColor: c.scaffold, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(l10n.login, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    l10n.welcomeSub,
                    style: TextStyle(color: c.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l10n.email, hintText: 'name@example.com'),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                        return context.tr('invalidEmail');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: l10n.password, hintText: context.tr('passwordHint')),
                    validator: (value) =>
                        (value ?? '').length < 6 ? context.tr('weakPassword') : null,
                    onFieldSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: c.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.login),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(context.tr('noAccount'), style: TextStyle(color: c.onSurfaceVariant)),
                      TextButton(
                        onPressed: () => context.go('/signup'),
                        child: Text(l10n.signup),
                      ),
                    ],
                  ),
                  Text(
                    context.tr('accountLocalNote'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: c.onSurfaceVariant, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = AppState.of(context);
    final result = await state.register(
      email: _email.text.trim(),
      password: _password.text,
      name: _name.text.trim(),
    );
    if (!mounted) return;
    if (result.ok) {
      context.go('/');
    } else {
      setState(() {
        _busy = false;
        _error = authErrorText(context, result.error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.glowColors;
    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(backgroundColor: c.scaffold, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(l10n.signup, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('accountLocalNote'),
                    style: TextStyle(color: c.onSurfaceVariant, height: 1.5, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l10n.name, hintText: context.tr('nameHint')),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l10n.email, hintText: 'name@example.com'),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                        return context.tr('invalidEmail');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: l10n.password, hintText: context.tr('passwordHint')),
                    validator: (value) =>
                        (value ?? '').length < 6 ? context.tr('weakPassword') : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: InputDecoration(labelText: l10n.confirmPassword),
                    validator: (value) =>
                        value != _password.text ? context.tr('pinMismatch') : null,
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: c.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.signup),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(context.tr('haveAccount'), style: TextStyle(color: c.onSurfaceVariant)),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(l10n.login),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
