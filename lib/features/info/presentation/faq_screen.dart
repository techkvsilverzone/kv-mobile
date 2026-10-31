import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/kv_ui.dart';
import '../../../core/widgets/links.dart';

/// Category → (question, answer) pairs, verbatim from kv-ui `pages/FAQ.tsx`.
const _faqData = <(String, List<(String, String)>)>[
  (
    'Purity & Certification',
    [
      (
        'What does Silver mean?',
        'Silver means the piece contains 92.5% pure silver and 7.5% other metals (usually copper) '
            'for added strength and durability. This is the international standard for high-quality '
            'silver jewelry. All KV Silver Zone products meet this standard.'
      ),
      (
        'What is BIS Hallmarking?',
        'BIS (Bureau of Indian Standards) Hallmarking is the official Indian certification for '
            'precious metals. A BIS hallmark guarantees the purity of the silver as declared. All '
            'products sold by KV Silver Zone are BIS Hallmarked, ensuring you get exactly what you '
            'pay for.'
      ),
      (
        'Do I receive a Certificate of Authenticity?',
        'Yes. Every purchase from KV Silver Zone comes with a Certificate of Authenticity, which '
            'includes the product details, weight, purity, and our verification seal. This document '
            'also supports buy-back and exchange claims.'
      ),
      (
        'Can I get an invoice for GST purposes?',
        'Absolutely. A GST-compliant invoice is generated for every order and shared via email. You '
            'can also download it from your Profile → Orders section. Our GSTIN is available on all '
            'invoices.'
      ),
    ],
  ),
  (
    'Ordering & Payment',
    [
      (
        'What payment methods do you accept?',
        'We accept all major payment methods through Razorpay: UPI (GPay, PhonePe, Paytm), debit and '
            'credit cards (Visa, Mastercard, RuPay, Amex), net banking, and digital wallets. Cash on '
            'Delivery (COD) is available for orders up to ₹15,000 in eligible pin codes.'
      ),
      (
        'Is it safe to pay online?',
        'Yes. All transactions are secured with 256-bit SSL encryption. We use Razorpay — a PCI DSS '
            'Level 1 compliant payment gateway — to process payments. We never store your card '
            'details on our servers.'
      ),
      (
        'Can I modify or cancel an order after placing it?',
        'Orders can be cancelled within 2 hours of placement by contacting our support team. Once '
            'dispatched, cancellations are not possible — you may initiate a return after delivery. '
            'For modifications, please call us immediately after ordering.'
      ),
      (
        'Do prices include GST?',
        'Yes. All prices displayed on our website are inclusive of 3% GST applicable on silver '
            'jewelry as per Indian tax regulations. You will see a full breakdown on your invoice.'
      ),
    ],
  ),
  (
    'Shipping & Delivery',
    [
      (
        'How long does delivery take?',
        'Standard delivery takes 5–7 business days across India. Metro cities like Chennai, Mumbai, '
            'Delhi, and Bangalore typically receive orders within 3–4 days. Remote pin codes may '
            'require additional time.'
      ),
      (
        'Are shipments insured?',
        'Yes. Every shipment from KV Silver Zone is fully insured against loss or damage during '
            'transit. In the rare event of a transit issue, we will replace or refund your order at '
            'no additional cost.'
      ),
      (
        'How do I track my order?',
        'Once your order is dispatched, you will receive an SMS and email with the tracking number '
            'and courier partner details. You can also track your order in real time via Profile → '
            'Orders → View Order.'
      ),
      (
        'Do you ship outside India?',
        'Currently, we ship only within India. International shipping is not available at this '
            'time. We hope to expand our reach in the future.'
      ),
    ],
  ),
  (
    'Returns, Exchanges & Buyback',
    [
      (
        'What is your return policy?',
        'Refunds and replacements are only available for KV-fault claims — a wrong, damaged, or '
            'defective item. These must be filed within 48 hours of delivery, and we require an '
            'unedited unboxing video (filmed continuously from before opening the sealed parcel '
            'through the full reveal) sent via WhatsApp to verify the claim. Change-of-mind requests '
            'are not eligible for a refund, but may qualify for an exchange or store credit — see '
            'below. Personalized or engraved items are non-returnable.'
      ),
      (
        'How do I initiate a return?',
        'Log in to your account, go to Profile → Orders, and select "Request Return" on the '
            "delivered order. Choose whether it's a KV-fault claim or a change-of-mind request. For "
            "KV-fault claims, you'll get a reference code — WhatsApp your unboxing video with that "
            'code as the caption within 48 hours of delivery. Once verified, refunds are processed '
            'in 5–7 business days.'
      ),
      (
        'Can I exchange for a different size or design?',
        'Yes. Change-of-mind requests (wrong size, design preference, etc.) are eligible for an '
            'exchange or store credit — not a cash refund, since silver/gold value fluctuates daily. '
            'No unboxing video is required for these. Exchange shipping costs are borne by the '
            'customer for the first request; subsequent exchanges may incur additional charges.'
      ),
      (
        'Do you offer a silver buyback?',
        'Yes. KV Silver Zone offers a buyback option at prevailing silver market rates at the time '
            'of transaction, minus applicable making charges and taxes. Buyback is subject to purity '
            'verification and is available in-store. Contact us to arrange an appointment.'
      ),
    ],
  ),
  (
    'Silver Care',
    [
      (
        'Why is my silver tarnishing?',
        'Tarnishing is a natural process caused by a reaction between silver and sulfur compounds in '
            'the air, water, and skin oils. It is not a defect. Silver is slightly more prone to '
            'tarnishing than pure silver due to the copper content, but tarnish can be easily '
            'removed.'
      ),
      (
        'How do I clean and maintain my silver jewelry?',
        'Clean with a soft, lint-free cloth regularly. For deeper cleaning, use a mild soap solution '
            'and a soft brush, then rinse and dry thoroughly. Avoid contact with chlorine, perfumes, '
            'lotions, and harsh chemicals. Store in an airtight pouch or the box provided to reduce '
            'tarnishing.'
      ),
      (
        'Can I wear silver while swimming or bathing?',
        'We strongly recommend removing silver jewelry before swimming (especially in chlorinated '
            'pools or saltwater) and bathing. Chlorine and salt water can accelerate tarnishing and '
            'damage the finish of your pieces.'
      ),
    ],
  ),
  (
    'Savings Scheme',
    [
      (
        'How does the KV Silver Zone Savings Scheme work?',
        'You enroll with a monthly installment amount (minimum ₹500) and a plan duration (6, 11, or '
            '17 months). After 11 regular payments, you earn a bonus 12th installment. At maturity, '
            'the accumulated amount can be redeemed against any silver purchase at zero making '
            'charges.'
      ),
      (
        'Can I withdraw before the scheme matures?',
        'Yes, you may exit early, but the bonus installment will be forfeited. Only the principal '
            'paid amounts will be credited toward a purchase. We recommend completing the full term '
            'for maximum benefit.'
      ),
      (
        'Are the monthly savings locked at a fixed silver rate?',
        'Savings amounts are monetary, not locked to a silver rate. The redemption value equals the '
            'total savings plus any bonus, used toward purchases at the prevailing price at the time '
            'of redemption.'
      ),
    ],
  ),
];

/// Port of kv-ui `pages/FAQ.tsx`: one category at a time, picked from a chip row,
/// each answer behind an expandable tile; "Still need help?" at the end.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _active = _faqData.first.$1;

  @override
  Widget build(BuildContext context) {
    final items = _faqData.firstWhere((c) => c.$1 == _active).$2;

    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(Kv.pad, 8, Kv.pad, 16),
          child: Text(
            'Everything you need to know about our silver, shopping experience, and the KV Silver Zone promise.',
            style: TextStyle(color: Kv.muted, fontSize: 14, height: 1.45),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
          child: Row(children: [
            for (final (category, _) in _faqData)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category),
                  selected: category == _active,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _active = category),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 20),
        SectionHeader(title: _active, subtitle: '${items.length} questions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
          child: KvCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, (question, answer)) in items.indexed) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                ExpansionTile(
                  // Keyed by question so switching category starts collapsed, as on web.
                  key: ValueKey(question),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  iconColor: Kv.blue,
                  collapsedIconColor: Kv.subtle,
                  title: Text(question, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
                  expandedAlignment: Alignment.centerLeft,
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(answer, style: const TextStyle(fontSize: 14, color: Kv.muted, height: 1.6)),
                  ],
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: Kv.gap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
          child: KvCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Kv.blueSoft,
                  child: Icon(Icons.support_agent_rounded, color: Kv.blue, size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Still need help?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('We respond to all enquiries within 4 business hours.',
                        style: TextStyle(color: Kv.muted, fontSize: 13)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openLink(storePhoneUri),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openLink(storeEmailUri),
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const Text('Email'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => context.push('/contact'),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Contact us'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
