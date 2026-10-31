import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart' show safeReturnPath;
import '../../../core/ui/kv_ui.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Sign in with a mobile code (default) or email + password. On success it
/// leaves explicitly: back to the page that opened it, or to [from], else Home.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});

  /// Set by the router when a sign-in-only page sent the user here.
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  int _mode = 0; // 0 = mobile code, 1 = email + password

  final _passwordFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _otpFormKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _obscure = true;
  bool _codeSent = false;

  @override
  void dispose() {
    for (final c in [_emailCtrl, _passwordCtrl, _phoneCtrl, _codeCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Leaves the sign-in screen. Pushed on top of a page → back to it (or on to
  /// the protected page that asked); opened as a root page → [from] or Home.
  Future<void> _signedIn() async {
    showKvToast(context, 'Welcome back!', message: 'You are signed in.');
    // Signing in refreshes the router, which re-applies the stack it read at that moment
    // (login included). Navigate once that refresh has landed, or it undoes the pop.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final from = widget.from;
    if (context.canPop()) {
      from != null ? context.pushReplacement(safeReturnPath(from)) : context.pop();
    } else {
      context.go(safeReturnPath(from));
    }
  }

  Future<void> _submitPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    final result =
        await ref.read(authControllerProvider.notifier).login(email: _emailCtrl.text, password: _passwordCtrl.text);
    if (!mounted) return;
    if (result.ok) {
      _signedIn();
    } else {
      showKvToast(context, 'Sign-in failed', message: result.error ?? 'Invalid email or password.', error: true);
    }
  }

  Future<void> _sendCode() async {
    if (!_otpFormKey.currentState!.validate()) return;
    final phone = _phoneCtrl.text.trim();
    final result = await ref.read(authControllerProvider.notifier).requestOtp(phone);
    if (!mounted) return;
    if (result.ok) {
      setState(() => _codeSent = true);
      showKvToast(context, 'Code sent', message: 'A 6-digit code is on its way to +91 ${normalizePhone(phone)}.');
    } else if (result.statusCode == 404) {
      showKvToast(
        context,
        'Number not registered',
        message: result.error,
        error: true,
        actionLabel: 'Sign up',
        // Carries the number over so it isn't typed twice.
        onAction: () => context.push('/signup', extra: normalizePhone(phone)),
      );
    } else {
      showKvToast(context, "Couldn't send the code", message: result.error ?? 'Please try again.', error: true);
    }
  }

  Future<void> _verifyCode() async {
    final result =
        await ref.read(authControllerProvider.notifier).verifyOtp(phone: _phoneCtrl.text, code: _codeCtrl.text);
    if (!mounted) return;
    if (result.ok) {
      _signedIn();
    } else if (result.statusCode != null) {
      showKvToast(context, 'Invalid code', message: 'That code is incorrect or has expired.', error: true);
    } else {
      showKvToast(context, 'Something went wrong', message: 'Please try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to track orders, save favourites and pay your savings instalments.',
      footer: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('New to KV Silver Zone?', style: TextStyle(color: Kv.muted)),
        TextButton(
          onPressed: busy ? null : () => context.push('/signup', extra: normalizePhone(_phoneCtrl.text)),
          child: const Text('Create account'),
        ),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AuthModeSwitch(
          labels: const ['Mobile number', 'Email & password'],
          index: _mode,
          onChanged: busy ? (_) {} : (i) => setState(() => _mode = i),
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _mode == 0 ? _otpForm(busy) : _passwordForm(busy),
        ),
      ]),
    );
  }

  Widget _otpForm(bool busy) {
    final phone = _phoneCtrl.text.trim();
    return Form(
      key: _otpFormKey,
      child: Column(key: const ValueKey('otp'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _phoneCtrl,
          enabled: !busy && !_codeSent,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onFieldSubmitted: (_) => busy || _codeSent ? null : _sendCode(),
          decoration: const InputDecoration(
            labelText: 'Mobile number',
            prefixIcon: Icon(Icons.phone_iphone_rounded),
            prefixText: '+91  ',
          ),
          validator: validatePhone,
        ),
        if (_codeSent) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _codeCtrl,
            enabled: !busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.w600),
            onChanged: (v) {
              setState(() {});
              if (v.length == 6 && !busy) _verifyCode();
            },
            decoration: const InputDecoration(labelText: 'Login code', hintText: '••••••', counterText: ''),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text('Sent to +91 ${normalizePhone(phone)}',
                  style: const TextStyle(fontSize: 13, color: Kv.muted)),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                        _codeSent = false;
                        _codeCtrl.clear();
                      }),
              child: const Text('Change number'),
            ),
          ]),
          TextButton(onPressed: busy ? null : _sendCode, child: const Text('Resend code')),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy
              ? null
              : _codeSent
                  ? (_codeCtrl.text.length == 6 ? _verifyCode : null)
                  : (phone.isEmpty ? null : _sendCode),
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(_codeSent ? 'Verify & sign in' : 'Send login code'),
        ),
      ]),
    );
  }

  Widget _passwordForm(bool busy) {
    return Form(
      key: _passwordFormKey,
      child: Column(key: const ValueKey('password'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _emailCtrl,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
          validator: validateEmail,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordCtrl,
          enabled: !busy,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => busy ? null : _submitPassword(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              tooltip: _obscure ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          // Not the 6-character signup rule: older accounts must still sign in.
          validator: validateLoginPassword,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: busy ? null : () => context.push('/forgot-password'),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: busy ? null : _submitPassword,
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : const Text('Sign in'),
        ),
      ]),
    );
  }
}
