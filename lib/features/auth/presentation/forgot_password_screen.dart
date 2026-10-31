import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/kv_ui.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/code_field.dart';

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
  bool _obscure = true;
  int _sends = 0; // restarts the resend countdown

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
      showKvToast(context, resend ? 'Code resent' : 'Reset code sent',
          message: 'If ${_emailCtrl.text.trim()} has an account, a 6-digit code is on its way.');
      setState(() {
        _codeSent = true;
        _sends++;
      });
    } else {
      showKvToast(context, 'Request failed',
          message: result.error ?? 'Unable to send a reset code right now.', error: true);
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
      showKvToast(context, 'Password reset', message: 'Sign in with your new password.');
      context.go('/login');
    } else {
      showKvToast(context, 'Reset failed',
          message: result.error ?? 'Unable to reset your password right now.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);

    return AuthScaffold(
      showBack: true,
      title: _codeSent ? 'Check your email' : 'Reset your password',
      subtitle: _codeSent
          ? 'Enter the code we emailed you and choose a new password.'
          : "Enter your account's email and we'll send you a 6-digit reset code.",
      footer: Center(
        child: TextButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
      ),
      child: _codeSent ? _resetStep(busy) : _emailStep(busy),
    );
  }

  Widget _emailStep(bool busy) => Form(
        key: _emailForm,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _emailCtrl,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => busy ? null : _sendCode(),
            decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
            validator: validateEmail,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : _sendCode, child: busy ? buttonSpinner : const Text('Send reset code')),
        ]),
      );

  Widget _resetStep(bool busy) => Form(
        key: _resetForm,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(color: Kv.bg, borderRadius: Kv.smallRadius),
            child: Row(children: [
              const Icon(Icons.mail_outline_rounded, size: 18, color: Kv.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_emailCtrl.text.trim(),
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: busy ? null : () => setState(() => _codeSent = false),
                child: const Text('Change'),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          CodeField(controller: _codeCtrl, label: 'Reset code', enabled: !busy, validator: validateOtpCode),
          Align(
            alignment: Alignment.centerRight,
            child: ResendCodeButton(key: ValueKey(_sends), onPressed: busy ? null : () => _sendCode(resend: true)),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _passwordCtrl,
            enabled: !busy,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: validatePassword,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmCtrl,
            enabled: !busy,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => busy ? null : _reset(),
            decoration:
                const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_outline_rounded)),
            validator: (v) => validateConfirmPassword(v, _passwordCtrl.text),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : _reset, child: busy ? buttonSpinner : const Text('Reset password')),
        ]),
      );
}
