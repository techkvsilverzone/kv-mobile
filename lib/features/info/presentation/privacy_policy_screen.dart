import 'package:flutter/material.dart';
import 'widgets/legal_section.dart';

/// Port of kv-ui `pages/PrivacyPolicy.tsx`; copy is verbatim.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strong = legalStrongStyle(context);
    return LegalPage(
      title: 'Privacy policy',
      meta: 'Last updated: April 2025  ·  Effective from: April 2025',
      children: [
        LegalIntro(
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'KV Silver Zone ("'),
              TextSpan(text: 'we', style: strong),
              const TextSpan(text: '", "'),
              TextSpan(text: 'us', style: strong),
              const TextSpan(text: '", or "'),
              TextSpan(text: 'our', style: strong),
              const TextSpan(
                  text: '") is committed to protecting your personal information. This Privacy '
                      'Policy explains how we collect, use, disclose, and safeguard your data when '
                      'you use our website or purchase our products.'),
            ]),
            style: legalBodyStyle(context),
          ),
        ),
        const LegalSection(title: '1. Information We Collect', children: [
          LegalText(
              'Name, email address, phone number, billing and shipping address collected during '
              'account registration or checkout.',
              lead: 'Personal Identification Information:'),
          LegalText(
              'We do not store card details on our servers. Payments are processed securely '
              'through Razorpay, which is PCI DSS compliant.',
              lead: 'Payment Information:'),
          LegalText(
              'Browser type, IP address, pages visited, and time spent on our site, collected '
              'automatically via cookies and analytics tools.',
              lead: 'Usage Data:'),
          LegalText(
              'Wishlist items, recently viewed products, and savings scheme enrollment data to '
              'personalize your experience.',
              lead: 'Preferences:'),
        ]),
        const LegalSection(title: '2. How We Use Your Information', children: [
          LegalText('Process and fulfill your orders, including shipping and delivery updates.', bullet: true),
          LegalText('Send order confirmations, invoices, and authenticity certificates.', bullet: true),
          LegalText('Respond to customer service enquiries and support requests.', bullet: true),
          LegalText('Send promotional communications (only with your consent; you may opt out at any time).',
              bullet: true),
          LegalText('Improve our website functionality, product recommendations, and user experience.', bullet: true),
          LegalText('Comply with legal obligations under Indian law (GST, consumer protection, etc.).', bullet: true),
        ]),
        const LegalSection(title: '3. Sharing of Information', children: [
          LegalText('We do not sell, trade, or rent your personal information to third parties. We may '
              'share data with:'),
          LegalText(
              'Shipping details are shared with our courier partners (e.g., BlueDart, DTDC) solely '
              'for delivery purposes.',
              lead: 'Logistics Partners:'),
          LegalText('Razorpay receives transaction data necessary to process payments securely.',
              lead: 'Payment Processors:'),
          LegalText('When required by law, court order, or governmental authority.', lead: 'Legal Authorities:'),
        ]),
        const LegalSection(title: '4. Cookies & Tracking', children: [
          LegalText('Our website uses cookies to maintain your session, remember cart items, and analyze '
              'traffic patterns. You may disable cookies in your browser settings, but this may '
              'affect the functionality of certain features.'),
          LegalText('We use Google Analytics to understand website usage. This data is anonymized and '
              'does not personally identify you.'),
        ]),
        const LegalSection(title: '5. Data Security', children: [
          LegalText('We implement industry-standard security measures including SSL/TLS encryption for '
              'all data transmission, secure server infrastructure, and access controls limiting '
              'who can view your data internally.'),
          LegalText('While we take every reasonable precaution, no transmission over the internet is '
              '100% secure. We encourage you to use strong, unique passwords for your account.'),
        ]),
        const LegalSection(title: '6. Data Retention', children: [
          LegalText('We retain your personal data for as long as your account is active or as needed to '
              'provide services. Order and payment records are kept for 7 years as required by GST '
              'regulations. You may request deletion of your account data by contacting us — '
              'subject to legal retention obligations.'),
        ]),
        const LegalSection(title: '7. Your Rights', children: [
          LegalText('Request a copy of the personal data we hold about you.', lead: 'Access:', bullet: true),
          LegalText('Update inaccurate information through your account profile.', lead: 'Correction:', bullet: true),
          LegalText('Request erasure of your personal data (subject to legal obligations).',
              lead: 'Deletion:', bullet: true),
          LegalText('Unsubscribe from marketing emails at any time via the link in any email.',
              lead: 'Opt-out:', bullet: true),
        ]),
        const LegalSection(title: "8. Children's Privacy", children: [
          LegalText('Our website and services are not directed at children under the age of 18. We do '
              'not knowingly collect personal data from minors. If you believe we have '
              'inadvertently collected such data, please contact us immediately.'),
        ]),
        LegalSection(title: '9. Contact Us', children: [
          const LegalText('For any privacy-related questions, requests, or concerns, please reach out:'),
          LegalContactBox(children: [
            Text('KV Silver Zone', style: legalBodyStyle(context)?.merge(strong)),
            const SizedBox(height: 4),
            const LegalText('14, Rajaram St, Gnanamoorthy Nagar Extn, Ambattur, Chennai 600053'),
            const SizedBox(height: 4),
            const LegalLinkLine(label: 'Email: ', links: ['kvszchennai@gmail.com']),
            const SizedBox(height: 4),
            const LegalLinkLine(label: 'Phone: ', links: ['(+91) 88256 49680']),
          ]),
        ]),
      ],
    );
  }
}
