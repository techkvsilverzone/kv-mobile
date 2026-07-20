import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/form_error_banner.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _acceptedTerms = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // The terms checkbox is not a TextFormField, so it validates separately.
    final formOk = _formKey.currentState!.validate();
    if (!_acceptedTerms) {
      setState(() => _error = 'Please accept the terms and conditions');
      return;
    }
    if (!formOk) return;
    setState(() => _error = null);

    final result = await ref.read(authControllerProvider.notifier).signup(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
    if (!mounted) return;

    if (!result.ok) {
      // The web's signup swallows failures entirely and shows nothing at all;
      // surfacing the message here is intentional.
      setState(() => _error = result.error);
      return;
    }

    final coupon = result.promoCoupon;
    if (coupon != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome! Use code $coupon for 10% off your first order.')),
      );
    }
    // Router redirects to /home on the auth-state change.
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);

    return AuthScaffold(
      showBack: true,
      title: 'Create your account',
      subtitle: 'Join KV Silver Zone',
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
              controller: _nameCtrl,
              enabled: !busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Full name',
                hintText: 'Your full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: validateName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              enabled: !busy,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 6 characters',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: validatePassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmCtrl,
              enabled: !busy,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) => validateConfirmPassword(v, _passwordCtrl.text),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: busy ? null : (v) => setState(() => _acceptedTerms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('I accept the terms and conditions'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
