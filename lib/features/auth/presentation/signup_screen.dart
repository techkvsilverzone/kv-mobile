import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/api/api_client.dart';
import '../../../core/ui/kv_ui.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/code_field.dart' show buttonSpinner;

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
      showKvToast(context, 'Could not create account',
          message: result.error ?? 'Something went wrong. Please try again.', error: true);
      return;
    }

    final coupon = result.promoCoupon;
    if (coupon != null) {
      showKvToast(context, 'Welcome! Promo coupon applied', message: 'Use code $coupon for 10% off your first order.');
    } else {
      showKvToast(context, 'Account created', message: 'Welcome to KV Silver Zone.');
    }
    // Leave explicitly: when signup sits on top of other pages, the router's auth
    // redirect doesn't reach it. Wait for the refresh that signing in triggers first.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    context.go(user != null && !user.phoneVerified && (user.phone ?? '').isNotEmpty ? '/verify-phone?sent=1' : '/home');
  }

  bool get _stallActive => widget.stallLink && (ref.read(stallActiveProvider).valueOrNull ?? false);

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    final stall = widget.stallLink && (ref.watch(stallActiveProvider).valueOrNull ?? false);
    const link = TextStyle(color: Kv.blue, fontWeight: FontWeight.w600);
    const gap = SizedBox(height: 14);

    return AuthScaffold(
      showBack: true,
      title: 'Create your account',
      subtitle: 'Join KV Silver Zone for exclusive offers.',
      footer: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton(onPressed: busy ? null : _submit, child: busy ? buttonSpinner : const Text('Create account')),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Already have an account?', style: TextStyle(color: Kv.muted)),
          TextButton(onPressed: busy ? null : () => context.go('/login'), child: const Text('Sign in')),
        ]),
      ]),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (stall) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Kv.goldSoft, borderRadius: Kv.smallRadius),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.local_offer_outlined, size: 20, color: Kv.gold),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Stall event offer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    SizedBox(height: 2),
                    Text('Register now and get a free promo coupon credited to your account.',
                        style: TextStyle(color: Kv.muted, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 20),
          ],
          TextFormField(
            controller: _nameCtrl,
            enabled: !busy,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
            validator: validateName,
          ),
          gap,
          TextFormField(
            controller: _phoneCtrl,
            enabled: !busy,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
              prefixText: '+91  ',
            ),
            validator: validatePhone,
          ),
          gap,
          TextFormField(
            controller: _emailCtrl,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
            validator: validateEmail,
          ),
          gap,
          TextFormField(
            controller: _passwordCtrl,
            enabled: !busy,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: validatePassword,
          ),
          gap,
          TextFormField(
            controller: _confirmCtrl,
            enabled: !busy,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            decoration:
                const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline_rounded)),
            validator: (v) => validateConfirmPassword(v, _passwordCtrl.text),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: Kv.smallRadius,
            onTap: busy ? null : () => setState(() => _acceptedTerms = !_acceptedTerms),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Checkbox(
                value: _acceptedTerms,
                onChanged: busy ? null : (v) => setState(() => _acceptedTerms = v ?? false),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(text: 'Terms of Service', style: link, recognizer: _termsTap),
                    const TextSpan(text: ' and '),
                    TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacyTap),
                  ]),
                  style: const TextStyle(color: Kv.muted, fontSize: 14, height: 1.4),
                ),
              ),
            ]),
          ),
          if (_termsError != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(_termsError!, style: const TextStyle(color: Kv.danger, fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}
