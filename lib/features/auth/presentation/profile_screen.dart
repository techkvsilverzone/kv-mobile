import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/validation/validators.dart';
import '../application/auth_controller.dart';
import 'widgets/form_error_banner.dart';

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

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
  }) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your profile has been updated.')),
      );
    } else {
      setState(() => _error = result.error);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll need to sign in again to place an order."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed == true) {
      // Clearing the session flips the router redirect back to /login.
      await ref.read(authSessionProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                    controller: _nameCtrl,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: validateName,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    enabled: !busy,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '+91 98765 43210',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    // Optional on the profile, unlike the address form.
                    validator: validateOptionalPhone,
                  ),
                  const SizedBox(height: 16),
                  _DateField(
                    label: 'Date of birth',
                    value: _dateOfBirth,
                    enabled: !busy,
                    onTap: () => _pickDate(
                      current: _dateOfBirth,
                      onPicked: (d) => setState(() => _dateOfBirth = d),
                    ),
                    onClear: () => setState(() => _dateOfBirth = null),
                  ),
                  const SizedBox(height: 16),
                  _DateField(
                    label: 'Wedding anniversary',
                    value: _anniversary,
                    enabled: !busy,
                    onTap: () => _pickDate(
                      current: _anniversary,
                      onPicked: (d) => setState(() => _anniversary = d),
                    ),
                    onClear: () => setState(() => _anniversary = null),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : _save,
                    child: busy
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save changes'),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Address book'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy ? null : () => context.push('/profile/addresses'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Change password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy ? null : () => context.push('/profile/password'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                    title: Text('Sign out',
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    onTap: busy ? null : _confirmSignOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: value == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear',
                  onPressed: enabled ? onClear : null,
                ),
        ),
        child: Text(
          value == null
              ? 'Not set'
              : '${value!.day.toString().padLeft(2, '0')}/'
                  '${value!.month.toString().padLeft(2, '0')}/${value!.year}',
        ),
      ),
    );
  }
}
