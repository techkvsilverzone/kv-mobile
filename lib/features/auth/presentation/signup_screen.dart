import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/validation/validators.dart';
import '../../savings/application/installment_payer.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// `GET /stall-config` `{data: {active}}`: whether offline-stall registration
/// is on. False on any failure, as on the web.
final stallActiveProvider = FutureProvider<bool>((ref) async {
  try {
    final res = await ref.watch(apiClientProvider).get('/stall-config');
    final cfg = res is Map && res['data'] is Map ? res['data'] : res;
    return cfg is Map && cfg['active'] == true;
  } catch (_) {
    return false;
  }
});

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.initialPhone, this.stallLink = false});

  /// Pre-fills the mobile field when the user arrives from a "not registered" login attempt.
  final String? initialPhone;

  /// Opened from a stall link (`?stall=1`). Only applies while the admin
  /// toggle is active server-side, so it can't be spoofed.
  final bool stallLink;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  late final _phoneCtrl = TextEditingController(text: widget.initialPhone);
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _acceptedTerms = false;
  String? _termsError;
  late final _termsTap = TapGestureRecognizer()..onTap = () => context.push('/terms');
  late final _privacyTap = TapGestureRecognizer()..onTap = () => context.push('/privacy-policy');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // The terms checkbox is not a TextFormField, so it validates separately.
    final formOk = _formKey.currentState!.validate();
    setState(() => _termsError = _acceptedTerms ? null : 'Please accept the terms and conditions');
    if (!formOk || !_acceptedTerms) return;

    final result = await ref.read(authControllerProvider.notifier).signup(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          phone: _phoneCtrl.text,
          password: _passwordCtrl.text,
          stallEvent: _stallActive,
        );
    if (!mounted) return;

    if (!result.ok) {
      showToast(context, 'Could not create account',
          result.error ?? 'Something went wrong. Please try again.',
          error: true);
      return;
    }

    final coupon = result.promoCoupon;
    if (coupon != null) {
      showToast(context, 'Welcome! Promo coupon applied 🎉',
          'Use code $coupon for 10% off your first order.');
    } else {
      showToast(context, 'Account created!', 'Welcome to KV Silver Zone.');
    }
    // The router moves on to phone verification (or home) on the auth-state change.
  }

  bool get _stallActive =>
      widget.stallLink && (ref.read(stallActiveProvider).valueOrNull ?? false);

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    final stall = widget.stallLink && (ref.watch(stallActiveProvider).valueOrNull ?? false);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final link = TextStyle(color: Theme.of(context).colorScheme.primary);

    return AuthScaffold(
      showBack: true,
      title: 'Create Account',
      subtitle: 'Join KV Silver Zone for exclusive offers',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stall) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Stall Event Offer!',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                              'Register now and receive a free promotional coupon automatically credited to your account.',
                              style: TextStyle(color: muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            TextFormField(
              controller: _nameCtrl,
              enabled: !busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Full Name',
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
                labelText: 'Email Address',
                hintText: 'your@email.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                hintText: '10-digit mobile number',
                helperText: "We'll send a verification code here after you sign up.",
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: validatePhone,
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
                hintText: '••••••••',
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
                labelText: 'Confirm Password',
                hintText: '••••••••',
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
              title: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(text: 'Terms of Service', style: link, recognizer: _termsTap),
                  const TextSpan(text: ' and '),
                  TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacyTap),
                ]),
                style: TextStyle(color: muted, fontSize: 14),
              ),
            ),
            if (_termsError != null)
              Text(_termsError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(busy ? 'Creating account...' : 'Create Account'),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Already have an account?', style: TextStyle(color: muted)),
                TextButton(
                  onPressed: busy ? null : () => context.go('/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
