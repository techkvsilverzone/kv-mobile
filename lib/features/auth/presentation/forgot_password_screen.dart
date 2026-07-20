import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/form_error_banner.dart';

/// IMPORTANT: `POST /auth/forgot-password` is a stub on `kv-api` — the
/// controller ignores the request body, sends no mail, and unconditionally
/// returns 200. The web app nonetheless tells the user "Reset link sent!",
/// which promises an email that never arrives.
///
/// This screen keeps the call (so it starts working the moment the endpoint is
/// implemented) but does not claim delivery. It leads with the login-code
/// route instead, which is fully implemented and genuinely gets a locked-out
/// user back in today.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final result = await ref.read(authControllerProvider.notifier).forgotPassword(_emailCtrl.text);
    if (!mounted) return;

    if (result.ok) {
      setState(() => _submitted = true);
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);

    return AuthScaffold(
      showBack: true,
      title: 'Trouble signing in?',
      subtitle: 'Get back into your account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign in with a login code',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    "We'll email you a 6-digit code — no password needed. "
                    'You can change your password from your profile once signed in.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: busy ? null : () => context.pop(),
                    child: const Text('Use a login code'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          if (_submitted)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your password reset request has been sent. '
                  'If you do not receive an email, sign in with a login code instead.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _submitted = false),
                  child: const Text('Try a different email'),
                ),
              ],
            )
          else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Request a password reset',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    FormErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send reset request'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
