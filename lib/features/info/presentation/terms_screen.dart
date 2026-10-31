import 'package:flutter/material.dart';
import '../../../core/widgets/page_header.dart';
import 'widgets/legal_section.dart';

/// Port of kv-ui `pages/TermsConditions.tsx`; copy is verbatim.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strong = legalStrongStyle(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const PageHeader(
            eyebrow: 'Legal',
            title: 'Terms & Conditions',
            subtitle: 'Last updated: April 2025  |  Governing Law: India',
          ),
          const SizedBox(height: 24),
          const LegalIntro(
            child: LegalText(
                'By accessing or purchasing from KV Silver Zone, you agree to be bound by these Terms '
                'and Conditions. Please read them carefully. If you do not agree, please discontinue '
                'use of our website.'),
          ),
          const LegalSection(title: '1. Eligibility', children: [
            LegalText(
                'You must be at least 18 years of age to make a purchase. By placing an order, you '
                'confirm that you are of legal age and have the legal capacity to enter into a '
                'binding contract under the laws of India.'),
          ]),
          const LegalSection(title: '2. Products & Pricing', children: [
            LegalText(
                'All products listed are subject to availability. Prices are displayed in Indian '
                'Rupees (INR) and include applicable GST (currently 3% on silver jewelry). Prices are '
                'subject to change without prior notice.'),
            LegalText(
                'Product images are representative. Slight variations in color, finish, or texture '
                'may exist due to photography lighting and screen calibration. All silver products '
                'are BIS Hallmarked (Silver unless stated otherwise).'),
            LegalText(
                'Weight mentioned is gross weight. Net metal weight may differ based on making '
                'charges and ornament design. Actual weights are verified at dispatch and are '
                'accurate within ±2% tolerance.'),
          ]),
          const LegalSection(title: '3. Orders & Payment', children: [
            LegalText(
                'Placing an order constitutes an offer to purchase. KV Silver Zone reserves the right '
                'to accept or decline any order at its discretion.'),
            LegalText(
                'Payments are processed securely via Razorpay. We accept UPI, debit/credit cards, net '
                'banking, and cash on delivery (COD) for eligible pin codes. COD orders are subject '
                'to a maximum order value of ₹15,000.'),
            LegalText(
                'In the event of a payment failure or dispute, contact us within 48 hours at '
                'kvszchennai@gmail.com with your order reference.'),
          ]),
          const LegalSection(title: '4. Shipping & Delivery', children: [
            LegalText(
                'All orders are dispatched within 24–48 hours of payment confirmation (excluding '
                'Sundays and national holidays). Standard delivery takes 5–7 business days across '
                'India.'),
            LegalText(
                'All shipments are fully insured against loss or damage in transit. Tracking details '
                'will be shared via SMS and email once dispatched.'),
            LegalText(
                'We currently ship only within India. Delivery to remote pin codes may take '
                'additional time. KV Silver Zone is not responsible for delays caused by courier '
                'partners or natural events.'),
          ]),
          LegalSection(title: '5. Returns, Exchanges & Refunds', children: [
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Refunds or replacements are available only for '),
                TextSpan(text: 'KV-fault claims', style: strong),
                const TextSpan(
                    text: ' — a wrong, damaged, or defective item — filed within 48 hours of '
                        'delivery. Every KV-fault claim requires an unedited unboxing video, filmed '
                        'continuously from before the sealed parcel is opened through the full '
                        'reveal, sent via WhatsApp to the number provided when the claim is filed and '
                        'referenced by its claim code. Claims without a matching video within the '
                        'window cannot be processed.'),
              ]),
              style: legalBodyStyle(context),
            ),
            const LegalText(
                '(size, design preference, or other non-fault reasons) are not eligible for a cash '
                'refund — silver and gold value fluctuates daily, so a melt-value refund is not '
                'offered — but may qualify for an exchange or store credit, subject to product '
                'availability, within 48 hours of delivery and no video is required.',
                lead: 'Change-of-mind requests'),
            const LegalText(
                'Personalized or engraved pieces, items showing signs of wear, and items damaged due '
                'to misuse.',
                lead: 'Non-Returnable Items:'),
            const LegalText(
                'Approved refunds are processed within 5–7 business days to the original payment '
                'method.'),
            const LegalText(
                'KV Silver Zone offers a buyback option at prevailing silver rates minus applicable '
                'making charges and taxes. Buyback is at our discretion and is subject to purity '
                'verification.',
                lead: 'Buyback Policy:'),
          ]),
          const LegalSection(title: '6. Savings Scheme', children: [
            LegalText(
                'The KV Silver Zone Monthly Savings Scheme is an in-store saving plan. Enrollment does '
                'not constitute a regulated financial product. The scheme allows customers to save a '
                'fixed monthly amount and redeem equivalent silver value at maturity, with an '
                'applicable bonus installment.'),
            LegalText(
                "KV Silver Zone reserves the right to modify scheme terms with 30 days' notice. "
                'Premature withdrawal may result in forfeiture of bonus benefits.'),
          ]),
          const LegalSection(title: '7. Intellectual Property', children: [
            LegalText(
                'All content on this website — including text, images, logos, and product designs — '
                'is the property of KV Silver Zone and is protected under applicable Indian copyright '
                'and trademark laws. Unauthorized reproduction or use is strictly prohibited.'),
          ]),
          const LegalSection(title: '8. Limitation of Liability', children: [
            LegalText(
                "KV Silver Zone's liability for any claim shall not exceed the value of the product "
                'purchased. We are not liable for indirect, incidental, or consequential damages '
                'arising from use of our products or website.'),
          ]),
          const LegalSection(title: '9. Governing Law & Dispute Resolution', children: [
            LegalText(
                'These terms are governed by the laws of India. Any disputes arising shall be subject '
                'to the exclusive jurisdiction of the courts in Chennai, Tamil Nadu.'),
            LegalText(
                'We encourage resolution through our customer support team before initiating any '
                'formal proceedings. Reach us at kvszchennai@gmail.com or (+91) 88256 49680.'),
          ]),
          const LegalSection(title: '10. Amendments', children: [
            LegalText(
                'KV Silver Zone reserves the right to update these Terms & Conditions at any time. '
                'Continued use of our website after changes constitutes your acceptance of the '
                'updated terms. We recommend checking this page periodically.'),
          ]),
          const SizedBox(height: 16),
          LegalContactBox(padding: 24, children: [
            Text('Contact Us',
                style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 16, fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            const LegalText('KV Silver Zone, 14 Rajaram St, Ambattur, Chennai 600053'),
            const LegalLinkLine(links: ['kvszchennai@gmail.com', '(+91) 88256 49680']),
          ]),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}
