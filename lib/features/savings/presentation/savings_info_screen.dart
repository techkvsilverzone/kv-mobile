import 'package:flutter/material.dart';
import '../../../core/ui/kv_ui.dart';

/// "How savings schemes work": the web's how-it-works steps and FAQ, kept off the tab root.
class SavingsInfoScreen extends StatelessWidget {
  const SavingsInfoScreen({super.key});

  static const _steps = [
    ('Choose', 'Pick the Gold, Silver or Diwali plan and a monthly amount.'),
    ('Save', 'Pay each month online with Razorpay, or in cash at the shop.'),
    ('Earn', 'Gold and Silver plans add a bonus month; the Diwali plan gives a festival hamper.'),
    ('Redeem', 'Exchange your savings for jewellery, coins or the hamper. Goods only, never cash.'),
  ];

  static const _faq = [
    ('What monthly amounts can I choose?',
        "Each plan publishes a fixed set of monthly amounts. Pick one when you enroll; it can't be changed mid-scheme."),
    ('What happens if I miss a payment?',
        'You can pay the next month, but your maturity date moves out by however many months you fell behind. Only one installment is accepted per calendar month.'),
    ('What if I need to stop early?',
        "You can exit any time before completing the scheme, but 10% of what you've paid is forfeited (plus the value of any gifts already received). The rest is redeemable as goods only, never as a cash refund."),
    ('How is the bonus calculated?',
        "The Gold and Silver Purchase Plans credit one bonus month's value (in grams, at that day's rate) once you complete all 11 real installments. The Diwali scheme has no bonus month; you receive the festival hamper instead."),
    ('Can I pay in cash instead of online?',
        'Yes. Visit the shop and our staff will record the cash payment on your passbook.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('How savings schemes work')),
        body: ListView(padding: const EdgeInsets.fromLTRB(Kv.pad, 16, Kv.pad, 32), children: [
          KvCard(
            child: Column(children: [
              for (final (i, (title, body)) in _steps.indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: i == _steps.length - 1 ? 0 : 16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Kv.goldSoft, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: Kv.gold)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(body, style: const TextStyle(color: Kv.muted, height: 1.4)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: Kv.gap),
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 10),
            child: Text('Questions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          KvCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, (q, a)) in _faq.indexed) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(q, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(a, style: const TextStyle(color: Kv.muted, height: 1.45))],
                  ),
                ),
              ],
            ]),
          ),
        ]),
      );
}
