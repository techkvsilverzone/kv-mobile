import 'package:flutter/material.dart';
import '../../../../core/ui/kv_ui.dart';

/// Surfaces the server's actual failure message above a form.
///
/// The web app discards these and shows one generic string for every failure,
/// so a network outage and a wrong password look identical. Showing the real
/// message is a deliberate improvement on the source, not a port of it.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Kv.dangerSoft, borderRadius: Kv.smallRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 20, color: Kv.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
