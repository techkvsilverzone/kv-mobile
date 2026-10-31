import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/ui/kv_ui.dart';

/// Big centred 6-digit code input (same look as the sign-in code field).
class CodeField extends StatelessWidget {
  const CodeField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.w600),
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        decoration: InputDecoration(labelText: label, hintText: '••••••', counterText: ''),
      );
}

/// "Resend code" that waits [seconds] after each send. Give it a new key after
/// every successful send to restart the countdown.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({super.key, required this.onPressed, this.countdown = true, this.seconds = 30});

  final VoidCallback? onPressed;

  /// False when no code has gone out yet, so the button is usable at once.
  final bool countdown;
  final int seconds;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  late int _left = widget.countdown ? widget.seconds : 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_left > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _left--);
        if (_left <= 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _left > 0
      ? TextButton(
          onPressed: null,
          child: Text('Resend code in 0:${_left.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Kv.muted, fontWeight: FontWeight.w500)),
        )
      : TextButton(onPressed: widget.onPressed, child: const Text('Resend code'));
}

/// Spinner sized for a filled button's label.
const buttonSpinner =
    SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white));
