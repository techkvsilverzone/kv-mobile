import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/ui/kv_ui.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/code_field.dart' show buttonSpinner;
import 'widgets/form_error_banner.dart';

/// "Personal details", pushed from the Account tab (which holds orders, addresses,
/// password and sign-out).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  DateTime? _dateOfBirth;
  DateTime? _anniversary;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _dateOfBirth = user?.dateOfBirth;
    _anniversary = user?.anniversaryDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required DateTime? current, required ValueChanged<DateTime?> onPicked}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final phone = _phoneCtrl.text.trim();
    final result = await ref.read(authControllerProvider.notifier).updateProfile({
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      // Send the normalized 10-digit form: the address endpoints reject
      // anything else, so storing a `+91`-prefixed value here would be
      // inconsistent with the rest of the account.
      'phone': phone.isEmpty ? '' : normalizePhone(phone),
      'dateOfBirth': _dateOfBirth?.toIso8601String(),
      'anniversaryDate': _anniversary?.toIso8601String(),
    });
    if (!mounted) return;

    if (result.ok) {
      showKvToast(context, 'Profile updated', message: 'Your details have been saved.');
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final initials = user.name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();
    final hasPhone = (user.phone ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Personal details')),
      bottomNavigationBar: BottomActionBar(
        action: FilledButton(onPressed: busy ? null : _save, child: busy ? buttonSpinner : const Text('Save changes')),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(Kv.pad, 24, Kv.pad, 24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Kv.ink,
                child: Text(initials.isEmpty ? '?' : initials,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            Text(user.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(user.email, textAlign: TextAlign.center, style: const TextStyle(color: Kv.muted, fontSize: 13)),
            if (hasPhone) ...[
              const SizedBox(height: 10),
              Center(
                child: user.phoneVerified
                    ? const StatusPill('Mobile verified', tone: PillTone.success, icon: Icons.verified_rounded)
                    : ActionChip(
                        avatar: const Icon(Icons.error_outline_rounded, size: 16, color: Kv.warning),
                        label: const Text('Verify mobile number'),
                        labelStyle: const TextStyle(color: Kv.warning, fontWeight: FontWeight.w600, fontSize: 13),
                        backgroundColor: Kv.warningSoft,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        onPressed: busy ? null : () => context.push('/verify-phone'),
                      ),
              ),
            ],
            const SizedBox(height: Kv.gap),
            if (_error != null) ...[
              FormErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            const _Caption('Contact'),
            KvCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _nameCtrl,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
                  validator: validateName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
                  validator: validateEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                    prefixText: '+91  ',
                  ),
                  // Optional on the profile, unlike the address form.
                  validator: validateOptionalPhone,
                ),
              ]),
            ),
            const SizedBox(height: Kv.gap),
            const _Caption('Special dates', note: "We'll send you something special."),
            KvCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _DateRow(
                  icon: Icons.cake_outlined,
                  label: 'Date of birth',
                  value: _dateOfBirth,
                  enabled: !busy,
                  onTap: () => _pickDate(current: _dateOfBirth, onPicked: (d) => setState(() => _dateOfBirth = d)),
                  onClear: () => setState(() => _dateOfBirth = null),
                ),
                const Divider(indent: 56),
                _DateRow(
                  icon: Icons.favorite_border_rounded,
                  label: 'Wedding anniversary',
                  value: _anniversary,
                  enabled: !busy,
                  onTap: () => _pickDate(current: _anniversary, onPicked: (d) => setState(() => _anniversary = d)),
                  onClear: () => setState(() => _anniversary = null),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {this.note});
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(text.toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Kv.muted)),
          if (note != null) ...[
            const Spacer(),
            Text(note!, style: const TextStyle(fontSize: 12, color: Kv.subtle)),
          ],
        ]),
      );
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return ListTile(
      onTap: enabled ? onTap : null,
      leading: Icon(icon, color: Kv.ink, size: 22),
      title: Text(label),
      subtitle: Text(
        v == null ? 'Add date' : '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}',
        style: TextStyle(color: v == null ? Kv.blue : Kv.muted, fontWeight: v == null ? FontWeight.w500 : null),
      ),
      trailing: v == null
          ? const Icon(Icons.chevron_right, color: Kv.subtle)
          : IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Kv.subtle),
              tooltip: 'Clear',
              onPressed: enabled ? onClear : null,
            ),
    );
  }
}
