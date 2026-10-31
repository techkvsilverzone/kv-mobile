import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/kv_ui.dart';
import '../application/auth_controller.dart';
import 'widgets/code_field.dart' show buttonSpinner;

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
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordCtrl.text;
    if (password.trim().isEmpty) {
      showKvToast(context, 'Password required', message: 'Please enter a new password.', error: true);
      return;
    }
    if (password != _confirmCtrl.text) {
      showKvToast(context, 'Passwords do not match',
          message: 'Confirm password must match the new password.', error: true);
      return;
    }

    final result = await ref.read(authControllerProvider.notifier).changePassword(password);
    if (!mounted) return;

    if (result.ok) {
      _passwordCtrl.clear();
      _confirmCtrl.clear();
      showKvToast(context, 'Password changed', message: 'Your password has been updated.');
    } else {
      showKvToast(context, 'Change password failed', message: passwordErrorMessage(result), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    final eye = IconButton(
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      tooltip: _obscure ? 'Show password' : 'Hide password',
      onPressed: () => setState(() => _obscure = !_obscure),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      bottomNavigationBar: BottomActionBar(
        action: FilledButton(onPressed: busy ? null : _submit, child: busy ? buttonSpinner : const Text('Update password')),
      ),
      body: ListView(padding: const EdgeInsets.all(Kv.pad), children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
          child: Text('Choose a strong password you don’t use anywhere else.',
              style: TextStyle(color: Kv.muted, fontSize: 14)),
        ),
        KvCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _passwordCtrl,
              enabled: !busy,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'New password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: eye,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmCtrl,
              enabled: !busy,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => busy ? null : _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
