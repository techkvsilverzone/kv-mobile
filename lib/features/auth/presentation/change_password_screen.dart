import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/form_error_banner.dart';

/// Matches the web: no current-password field, because `PUT /users/:id/password`
/// does not ask for one. The route is behind auth, so possession of a valid
/// token is the only proof required.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final result =
        await ref.read(authControllerProvider.notifier).changePassword(_passwordCtrl.text);
    if (!mounted) return;

    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your password has been changed.')),
      );
      context.pop();
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    FormErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _passwordCtrl,
                    enabled: !busy,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'New password',
                      helperText: 'At least 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    // The web omits this check client-side and lets the server
                    // reject it; validating here avoids the wasted round trip.
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmCtrl,
                    enabled: !busy,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => validateConfirmPassword(v, _passwordCtrl.text),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Update password'),
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
