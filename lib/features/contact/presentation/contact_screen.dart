import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/ui/kv_ui.dart';
import '../../../core/validation/validators.dart';
import '../../info/presentation/widgets/store_card.dart';
import '../data/contact_repository.dart';

/// Select value → label, as in the web's Subject `<Select>`. The value (not
/// the label) is what gets sent.
const _subjects = {
  'order': 'Order Inquiry',
  'product': 'Product Question',
  'savings': 'Savings Scheme',
  'return': 'Returns & Exchange',
  'other': 'Other',
};

String? _validateMessage(String? value) =>
    (value ?? '').trim().length < 10 ? 'Please enter at least 10 characters' : null;

/// Port of kv-ui `pages/Contact.tsx`.
class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  String? _subject;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      // Same body as the web: values are sent untrimmed and phone is validated
      // but not sent (the endpoint has no phone field).
      await ref.read(contactRepositoryProvider).sendEnquiry({
        'name': _name.text,
        'email': _email.text,
        'subject': _subject ?? 'General Enquiry',
        'message': _message.text,
      });
      if (mounted) showKvToast(context, 'Message sent', message: 'Our team will get back to you within 24 hours.');
      _name.clear();
      _email.clear();
      _phone.clear();
      _message.clear();
      _subject = null;
    } on ApiException catch (e) {
      if (mounted) {
        showKvToast(context, 'Message failed',
            message: e.message.isEmpty ? 'Unable to send message right now.' : e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);

    return Scaffold(
      appBar: AppBar(title: const Text('Contact us')),
      bottomNavigationBar: BottomActionBar(
        action: FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 18),
          label: const Text('Send message'),
        ),
      ),
      // Not a ListView: a lazily built list would drop off-screen form fields
      // and Form.validate() would skip them.
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(Kv.pad, 8, Kv.pad, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text(
              "Have questions? We're here to help. Reach out to our friendly support team and we'll get back to "
              'you as soon as possible.',
              style: TextStyle(color: Kv.muted, fontSize: 14, height: 1.45),
            ),
          ),
          const StoreActions(),
          const SizedBox(height: Kv.gap),
          const SectionHeader(title: 'Send us a message', padding: EdgeInsets.fromLTRB(4, 0, 4, 10)),
          KvCard(
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: validateName,
                ),
                gap,
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                ),
                gap,
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91  '),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: validatePhone,
                ),
                gap,
                DropdownButtonFormField<String>(
                  initialValue: _subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  hint: const Text('Select a topic'),
                  borderRadius: Kv.smallRadius,
                  items: [
                    for (final e in _subjects.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _subject = v),
                ),
                gap,
                TextFormField(
                  controller: _message,
                  decoration: const InputDecoration(
                      labelText: 'Message', hintText: 'Tell us how we can help...', alignLabelWithHint: true),
                  minLines: 4,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  validator: _validateMessage,
                ),
              ]),
            ),
          ),
          const SizedBox(height: Kv.gap),
          const SectionHeader(title: 'Visit the showroom', padding: EdgeInsets.fromLTRB(4, 0, 4, 10)),
          // Stands in for the web's Google Maps embed.
          const StoreCard(),
        ]),
      ),
    );
  }
}
