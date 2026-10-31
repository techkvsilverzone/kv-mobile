import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/validation/validators.dart';
import '../../savings/application/installment_payer.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Two steps: email a reset code (`POST /auth/forgot-password`), then redeem it
/// with a new password (`POST /auth/reset-password`).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _codeSent = false;

  @override
  void dispose() {
    for (final c in [_emailCtrl, _codeCtrl, _passwordCtrl, _confirmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_emailForm.currentState!.validate()) return;
    final result = await ref.read(authControllerProvider.notifier).forgotPassword(_emailCtrl.text);
    if (!mounted) return;
    if (result.ok) {
      showToast(context, resend ? 'Code resent' : 'Reset code sent!',
          'If ${_emailCtrl.text.trim()} has an account, a 6-digit code is on its way.');
      setState(() => _codeSent = true);
    } else {
      showToast(context, 'Request failed', result.error ?? 'Unable to send a reset code right now.', error: true);
    }
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    final result = await ref.read(authControllerProvider.notifier).resetPassword(
          email: _emailCtrl.text,
          code: _codeCtrl.text,
          newPassword: _passwordCtrl.text,
        );
    if (!mounted) return;
    if (result.ok) {
      showToast(context, 'Password reset', 'Sign in with your new password.');
      context.go('/login');
    } else {
      showToast(context, 'Reset failed', result.error ?? 'Unable to reset your password right now.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return AuthScaffold(
      showBack: true,
      title: 'Reset Password',
      subtitle: _codeSent
          ? 'Enter the code we emailed you and choose a new password'
          : 'Enter your email to receive a reset code',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_codeSent)
          Form(
            key: _resetForm,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Code sent to '),
                  TextSpan(text: _emailCtrl.text.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _codeCtrl,
                enabled: !busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 8),
                decoration: const InputDecoration(labelText: 'Reset Code', hintText: '000000'),
                validator: validateOtpCode,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                enabled: !busy,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_outline)),
                validator: validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                enabled: !busy,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm New Password', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => validateConfirmPassword(v, _passwordCtrl.text),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: busy ? null : _reset, child: Text(busy ? 'Resetting...' : 'Reset Password')),
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy ? null : () => _sendCode(resend: true),
                child: const Text('Resend code'),
              ),
              TextButton(
                onPressed: busy ? null : () => setState(() => _codeSent = false),
                child: const Text('Use a different email'),
              ),
            ]),
          )
        else
          Form(
            key: _emailForm,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _emailCtrl,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'your@email.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: busy ? null : _sendCode, child: Text(busy ? 'Sending...' : 'Send Reset Code')),
            ]),
          ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to login'),
          ),
        ),
      ]),
    );
  }
}
