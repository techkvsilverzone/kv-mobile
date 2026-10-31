import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/ui/kv_ui.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/code_field.dart';
import 'widgets/form_error_banner.dart';

/// Confirms the account's mobile number with the code sent on WhatsApp. Optional, like the
/// web: the scaffold's Skip (or back, when pushed) always lets the customer carry on, and
/// Account offers it again later.
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
  late int _sends = widget.codeAlreadySent ? 1 : 0; // restarts the resend countdown

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
      setState(() => _sends++);
      showKvToast(context, 'Code sent', message: 'A new code has been sent on WhatsApp.');
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
    showKvToast(context, 'Number verified', message: 'Your mobile number is verified.');
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_error != null) ...[
            FormErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          CodeField(
            controller: _codeCtrl,
            label: 'Verification code',
            enabled: !busy,
            autofocus: true,
            validator: validateOtpCode,
            onSubmitted: (_) => busy ? null : _verify(),
            onChanged: (v) {
              setState(() {});
              // Six digits submit on their own, as on sign-in.
              if (v.length == 6 && !busy) _verify();
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.chat_outlined, size: 16, color: Kv.muted),
            const SizedBox(width: 6),
            const Expanded(child: Text('Check WhatsApp', style: TextStyle(fontSize: 13, color: Kv.muted))),
            ResendCodeButton(key: ValueKey(_sends), countdown: _sends > 0, onPressed: busy ? null : _resend),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy || _codeCtrl.text.length < 6 ? null : _verify,
            child: busy ? buttonSpinner : const Text('Verify'),
          ),
        ]),
      ),
    );
  }
}
