import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/form_error_banner.dart';

/// Confirms the account's mobile number with the code sent on WhatsApp. Optional, like the
/// web: "Skip for now" always lets the customer carry on, and Profile offers it again later.
class PhoneVerificationScreen extends ConsumerStatefulWidget {
  const PhoneVerificationScreen({super.key, this.codeAlreadySent = false});

  /// True straight after signup, where the API has already sent the first code.
  final bool codeAlreadySent;

  @override
  ConsumerState<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends ConsumerState<PhoneVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.codeAlreadySent) Future.microtask(_resend);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    final result = await ref.read(authControllerProvider.notifier).requestPhoneVerification();
    if (!mounted) return;
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent on WhatsApp.')),
      );
    } else {
      setState(() => _error = result.error);
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final result = await ref.read(authControllerProvider.notifier).verifyPhone(_codeCtrl.text);
    if (!mounted) return;

    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your mobile number is verified.')),
    );
    _leave();
  }

  void _leave() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    final phone = ref.watch(currentUserProvider)?.phone ?? '';

    return AuthScaffold(
      showBack: context.canPop(),
      title: 'Verify your mobile',
      subtitle: 'Enter the 6-digit code sent on WhatsApp to +91 $phone',
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
              controller: _codeCtrl,
              enabled: !busy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onFieldSubmitted: (_) => busy ? null : _verify(),
              decoration: const InputDecoration(
                labelText: 'Verification code',
                prefixIcon: Icon(Icons.pin_outlined),
                counterText: '',
              ),
              validator: validateOtpCode,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: busy ? null : _verify,
              child: busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify'),
            ),
            TextButton(
              onPressed: busy ? null : _resend,
              child: const Text('Resend code'),
            ),
            TextButton(
              onPressed: busy ? null : _leave,
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}
