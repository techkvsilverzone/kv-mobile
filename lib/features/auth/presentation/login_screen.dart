import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/form_error_banner.dart';

/// Two ways in, matching the web: email+password, or a 6-digit code emailed to
/// the user (`/auth/otp/request` → `/auth/otp/verify`). Both return the same
/// `{user, token}` envelope, so the session handling is identical.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  final _passwordFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _otpEmailFormKey = GlobalKey<FormState>();
  final _otpCodeFormKey = GlobalKey<FormState>();
  final _otpEmailCtrl = TextEditingController();
  final _otpCodeCtrl = TextEditingController();

  bool _obscure = true;
  bool _codeSent = false;
  String? _error;

  @override
  void dispose() {
    _tabs.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _otpEmailCtrl.dispose();
    _otpCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _error = null);

    final result = await ref.read(authControllerProvider.notifier).login(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
    if (!mounted) return;

    // On success the router redirects automatically off the auth-state change —
    // no explicit navigation here.
    if (!result.ok) setState(() => _error = result.error);
  }

  Future<void> _sendCode() async {
    if (!_otpEmailFormKey.currentState!.validate()) return;
    setState(() => _error = null);

    final result = await ref.read(authControllerProvider.notifier).requestOtp(_otpEmailCtrl.text);
    if (!mounted) return;

    if (result.ok) {
      setState(() => _codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Check ${_otpEmailCtrl.text.trim()} for your login code.')),
      );
    } else {
      setState(() => _error = result.error);
    }
  }

  Future<void> _verifyCode() async {
    if (!_otpCodeFormKey.currentState!.validate()) return;
    setState(() => _error = null);

    final result = await ref.read(authControllerProvider.notifier).verifyOtp(
          email: _otpEmailCtrl.text,
          code: _otpCodeCtrl.text,
        );
    if (!mounted) return;

    if (!result.ok) setState(() => _error = result.error);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue shopping',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabs,
            onTap: (_) => setState(() => _error = null),
            tabs: const [Tab(text: 'Password'), Tab(text: 'Login code')],
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            FormErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          // A fixed height keeps the tab view from fighting the scroll view for
          // an unbounded constraint.
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabs,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildPasswordTab(busy), _buildOtpTab(busy)],
            ),
          ),
          const SizedBox(height: 8),
          // Wrap, not Row: the label plus button exceeds the form width on
          // narrow phones and must reflow rather than overflow.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(
                onPressed: busy ? null : () => context.push('/signup'),
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
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => busy ? null : _submitPassword(),
            decoration: InputDecoration(
              labelText: 'Password',
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
            child: busy ? const _ButtonSpinner() : const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpTab(bool busy) {
    if (!_codeSent) {
      return Form(
        key: _otpEmailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("We'll email you a 6-digit code to sign in with."),
            const SizedBox(height: 16),
            TextFormField(
              controller: _otpEmailCtrl,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : _sendCode,
              child: busy ? const _ButtonSpinner() : const Text('Send login code'),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _otpCodeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter the code sent to ${_otpEmailCtrl.text.trim()}.'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpCodeCtrl,
            enabled: !busy,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Login code',
              prefixIcon: Icon(Icons.pin_outlined),
              counterText: '',
            ),
            validator: validateOtpCode,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: busy ? null : _verifyCode,
            child: busy ? const _ButtonSpinner() : const Text('Sign in'),
          ),
          TextButton(
            onPressed: busy ? null : _sendCode,
            child: const Text('Resend code'),
          ),
          TextButton(
            onPressed: busy ? null : () => setState(() => _codeSent = false),
            child: const Text('Use a different email'),
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
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
