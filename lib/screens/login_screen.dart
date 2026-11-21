import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../providers/auth_providers.dart';
import '../services/auth/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  AppRole _role = AppRole.user;
  bool _obscurePassword = true;
  bool _busy = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Runs one sign-in at a time, so repeated taps can't send duplicate requests.
  Future<void> _attempt(Future<void> Function(AuthService) signIn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      await signIn(ref.read(authServiceProvider));
    } on AuthFailure catch (e) {
      if (mounted && !e.cancelled) setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submitAdmin() {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    _attempt(
      (auth) => auth.signInAsAdmin(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/logo/logo.png',
                        width: 72,
                        height: 72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Expense Splitter',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  Text('Sign in as', style: theme.textTheme.titleMedium),
                  RadioGroup<AppRole>(
                    groupValue: _role,
                    onChanged: (role) {
                      if (_busy || role == null) return;
                      setState(() {
                        _role = role;
                        _errorText = null;
                      });
                    },
                    child: const Row(
                      children: [
                        Expanded(
                          child: RadioListTile<AppRole>(
                            value: AppRole.user,
                            title: Text('User'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<AppRole>(
                            value: AppRole.admin,
                            title: Text('Admin'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_role == AppRole.user)
                    _buildUserLogin()
                  else
                    _buildAdminLogin(),
                  if (_errorText != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorText!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserLogin() {
    return FilledButton.icon(
      onPressed: _busy
          ? null
          : () => _attempt((auth) => auth.signInWithGoogle()),
      icon: _busy ? const _ButtonSpinner() : const Icon(Icons.login),
      label: const Text('Sign in with Google'),
    );
  }

  Widget _buildAdminLogin() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usernameController,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Username'),
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter your username'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitAdmin(),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Enter your password' : null,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submitAdmin,
            icon: _busy ? const _ButtonSpinner() : const Icon(Icons.lock_open),
            label: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
