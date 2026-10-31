import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/validation/validators.dart';
import '../../savings/application/installment_payer.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// kv-ui pages/Login.tsx: Mobile + OTP (primary) or email + password. Both
/// return the same `{user, token}`; on success the router redirects off the
/// auth-state change, so there is no explicit navigation here.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  final _passwordFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _otpPhoneFormKey = GlobalKey<FormState>();
  final _otpPhoneCtrl = TextEditingController();
  final _otpCodeCtrl = TextEditingController();

  bool _obscure = true;
  bool _codeSent = false;

  @override
  void dispose() {
    _tabs.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _otpPhoneCtrl.dispose();
    _otpCodeCtrl.dispose();
    super.dispose();
  }

  void _welcome() => showToast(context, 'Welcome back!', 'You have successfully logged in.');

  Future<void> _submitPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    final result = await ref.read(authControllerProvider.notifier).login(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    if (result.ok) {
      _welcome();
    } else {
      // The web says "Invalid email or password." for every failure, even an
      // outage; the server's own message is shown instead.
      showToast(context, 'Login failed', result.error ?? 'Invalid email or password.', error: true);
    }
  }

  Future<void> _sendCode() async {
    final phone = _otpPhoneCtrl.text.trim();
    if (phone.isEmpty) {
      showToast(context, 'Mobile number required', 'Enter your mobile number to receive a code.',
          error: true);
      return;
    }
    if (!_otpPhoneFormKey.currentState!.validate()) return;

    final result = await ref.read(authControllerProvider.notifier).requestOtp(phone);
    if (!mounted) return;

    if (result.ok) {
      setState(() => _codeSent = true);
      showToast(context, 'Code sent', 'A login code is on its way to your mobile number.');
    } else if (result.statusCode == 404) {
      final messenger = ScaffoldMessenger.of(context);
      final scheme = Theme.of(context).colorScheme;
      messenger.showSnackBar(SnackBar(
        backgroundColor: scheme.error,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Number not registered', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(result.error ?? ''),
          ],
        ),
        action: SnackBarAction(
          label: 'Sign up',
          textColor: scheme.onError,
          // Carries the number over so the user doesn't retype it.
          onPressed: () => context.push('/signup', extra: normalizePhone(phone)),
        ),
      ));
    } else {
      showToast(context, 'Error', result.error ?? 'Could not send the code. Please try again.',
          error: true);
    }
  }

  Future<void> _verifyCode() async {
    final result = await ref.read(authControllerProvider.notifier).verifyOtp(
          phone: _otpPhoneCtrl.text,
          code: _otpCodeCtrl.text,
        );
    if (!mounted) return;
    if (result.ok) {
      _welcome();
    } else if (result.statusCode != null) {
      showToast(context, 'Invalid code', 'That code is incorrect or has expired.', error: true);
    } else {
      showToast(context, 'Error', 'Something went wrong. Please try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return AuthScaffold(
      title: 'Welcome Back',
      subtitle: 'Sign in to your KV Silver Zone account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabs,
            onTap: (_) => setState(() {}),
            tabs: const [Tab(text: 'Mobile + OTP'), Tab(text: 'Password')],
          ),
          const SizedBox(height: 24),
          if (_tabs.index == 0) _buildOtpTab(busy) else _buildPasswordTab(busy),
          const SizedBox(height: 16),
          // Wrap, not Row: the label plus button exceeds the form width on
          // narrow phones and must reflow rather than overflow.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text("Don't have an account?", style: TextStyle(color: muted)),
              TextButton(
                // Carries a typed mobile number over, so a "not registered" user doesn't retype it.
                onPressed: busy
                    ? null
                    : () => context.push('/signup', extra: normalizePhone(_otpPhoneCtrl.text)),
                child: const Text('Sign up'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTab(bool busy) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailCtrl,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'your@email.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
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
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            // Not the 6-character signup rule: accounts created before that rule
            // must still be able to sign in.
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
            child: Text(busy ? 'Signing in...' : 'Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpTab(bool busy) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final phone = _otpPhoneCtrl.text.trim();
    return Form(
      key: _otpPhoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _otpPhoneCtrl,
            enabled: !busy && !_codeSent,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => setState(() => _codeSent = false),
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              hintText: '10-digit mobile number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: validatePhone,
          ),
          const SizedBox(height: 24),
          if (!_codeSent)
            FilledButton(
              onPressed: busy || phone.isEmpty ? null : _sendCode,
              child: Text(busy ? 'Sending code...' : 'Send Login Code'),
            )
          else ...[
            TextFormField(
              controller: _otpCodeCtrl,
              enabled: !busy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Login Code',
                hintText: '6-digit code',
                prefixIcon: const Icon(Icons.key_outlined),
                counterText: '',
                helperText: 'Sent to +91 ${normalizePhone(phone)}',
              ),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton(
                  // The web disables the number once a code is sent, leaving no
                  // way to correct it; this re-enables it.
                  onPressed: busy ? null : () => setState(() => _codeSent = false),
                  child: Text('Use a different number', style: TextStyle(color: muted)),
                ),
                TextButton(
                  onPressed: busy ? null : _sendCode,
                  child: const Text('Resend code'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: busy || _otpCodeCtrl.text.length != 6 ? null : _verifyCode,
              child: Text(busy ? 'Verifying...' : 'Verify & Sign In'),
            ),
          ],
        ],
      ),
    );
  }
}
