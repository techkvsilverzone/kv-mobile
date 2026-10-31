import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../savings/application/installment_payer.dart';
import '../application/auth_controller.dart';

/// kv-ui pages/ChangePassword.tsx. No current-password field, because
/// `PUT /users/:id/password` does not ask for one; the route is behind auth.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

/// Web `getPasswordErrorMessage`.
String passwordErrorMessage(AuthSubmission r) => switch (r.statusCode) {
      400 => 'Password is weak or invalid. Please use a stronger password.',
      403 => "You are not allowed to change another user's password.",
      404 => 'User not found.',
      _ => r.error ?? 'Failed to change password.',
    };

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordCtrl.text;
    if (password.trim().isEmpty) {
      showToast(context, 'Password required', 'Please enter a new password.', error: true);
      return;
    }
    if (password != _confirmCtrl.text) {
      showToast(context, 'Passwords do not match', 'Confirm password must match the new password.',
          error: true);
      return;
    }

    final result = await ref.read(authControllerProvider.notifier).changePassword(password);
    if (!mounted) return;

    if (result.ok) {
      _passwordCtrl.clear();
      _confirmCtrl.clear();
      showToast(context, 'Password changed', 'Your password has been updated successfully.');
    } else {
      showToast(context, 'Change password failed', passwordErrorMessage(result), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Change Password',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Update your account password securely.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordCtrl,
                    enabled: !busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter new password',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmCtrl,
                    enabled: !busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      hintText: 'Confirm new password',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Updating...'),
                            ],
                          )
                        : const Text('Update Password'),
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
