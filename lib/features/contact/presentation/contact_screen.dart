import 'package:flutter/material.dart';
import '../../../core/widgets/links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/page_header.dart';
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

const _address = '14, Rajaram St, Gnanamoorthy Nagar Extension\n'
    'Town Planning Colony, Ambattur\n'
    'Chennai, Tamil Nadu 600053';

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

  SnackBar _toast(String title, String description, {bool error = false}) {
    final cs = Theme.of(context).colorScheme;
    final fg = error ? cs.onError : null;
    return SnackBar(
      backgroundColor: error ? cs.error : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
          Text(description, style: TextStyle(color: fg)),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(_toast('Message Sent!', 'Our team will get back to you within 24 hours.'));
      _name.clear();
      _email.clear();
      _phone.clear();
      _message.clear();
      _subject = null;
    } on ApiException catch (e) {
      messenger.showSnackBar(_toast(
        'Message failed',
        e.message.isEmpty ? 'Unable to send message right now.' : e.message,
        error: true,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant;
    final sectionHeading = theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold);
    const gap = SizedBox(height: 16);

    Widget storeRow(IconData icon, String title, Widget body) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: cs.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    body,
                  ],
                ),
              ),
            ],
          ),
        );
    final mutedSmall = theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1.6);

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      // Not a ListView: a lazily built list would drop off-screen form fields
      // and Form.validate() would skip them.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text('Contact Support',
                      textAlign: TextAlign.center,
                      // The web hardcodes `text-white` on this heading.
                      style: theme.textTheme.headlineLarge
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Text(
                    "Have questions? We're here to help. Reach out to our friendly support team and "
                    "we'll get back to you as soon as possible.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const InfoCard(icon: Icons.location_on_outlined, title: 'Visit Us', body: _address),
            gap,
            const InfoCard(icon: Icons.phone_outlined, title: 'Call Us', body: '(+91) 88256 49680'),
            gap,
            const InfoCard(icon: Icons.mail_outline, title: 'Email Us', body: 'kvszchennai@gmail.com'),
            gap,
            const InfoCard(
                icon: Icons.schedule,
                title: 'Working Hours',
                body: 'Mon - Sat: 10:00 AM - 8:00 PM\nSunday: Closed'),
            const SizedBox(height: 48),
            Text('Send Us a Message', style: sectionHeading),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Your name'),
                    textInputAction: TextInputAction.next,
                    validator: validateName,
                  ),
                  gap,
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(
                        labelText: 'Email Address', hintText: 'your@email.com'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: validateEmail,
                  ),
                  gap,
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone Number', hintText: '+91 98765 43210'),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: validatePhone,
                  ),
                  gap,
                  DropdownButtonFormField<String>(
                    initialValue: _subject,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    hint: const Text('Select a topic'),
                    items: [
                      for (final e in _subjects.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _subject = v),
                  ),
                  gap,
                  TextFormField(
                    controller: _message,
                    decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Tell us how we can help...',
                        alignLabelWithHint: true),
                    minLines: 5,
                    maxLines: 5,
                    validator: _validateMessage,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_submitting ? 'Sending...' : 'Send Message'),
                        const SizedBox(width: 8),
                        const Icon(Icons.send, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Text('Quick Help', style: sectionHeading),
            const SizedBox(height: 24),
            Text('Store Information', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            storeRow(
              Icons.location_on_outlined,
              'Visit Us',
              Text(
                '14, Rajaram St,\nGnanamoorthy Nagar Extension,\nTown Planning Colony, Ambattur,\n'
                'Chennai, Tamil Nadu 600053',
                style: mutedSmall,
              ),
            ),
            storeRow(Icons.phone_outlined, 'Call Us', Text('(+91) 88256 49680', style: mutedSmall)),
            storeRow(Icons.mail_outline, 'Email Us', Text('kvszchennai@gmail.com', style: mutedSmall)),
            Card(
              margin: EdgeInsets.zero,
              color: cs.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Icon(Icons.chat_bubble_outline, size: 40, color: cs.onSecondaryContainer),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Live Chat',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
                          Text('Available 10AM - 8PM',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSecondaryContainer.withValues(alpha: 0.8))),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () => openLink(storeWhatsAppUri),
                        child: const Text('Start Chat'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Stands in for the web's Google Maps embed.
            const InfoCard(
                icon: Icons.map_outlined, title: 'KV Silver Zone Location', body: _address),
          ],
        ),
      ),
    );
  }
}
