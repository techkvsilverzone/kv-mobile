import 'package:flutter/material.dart';
import '../../../../core/ui/kv_ui.dart';
import '../../../../core/widgets/links.dart';

const storeAddress = '14, Rajaram St, Gnanamoorthy Nagar Extension, Town Planning Colony, Ambattur, '
    'Chennai, Tamil Nadu 600053';
const storePhone = '(+91) 88256 49680';
const storeEmail = 'kvszchennai@gmail.com';

/// Call / WhatsApp / Email as three equal tiles.
class StoreActions extends StatelessWidget {
  const StoreActions({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, String sub, Color bg, Color fg, String uri) => Expanded(
          child: KvCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            onTap: () => openLink(uri),
            child: Column(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: fg, size: 22),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: Kv.muted, fontSize: 12)),
            ]),
          ),
        );
    return Row(children: [
      tile(Icons.call_outlined, 'Call', '10 AM – 8 PM', Kv.blueSoft, Kv.blue, storePhoneUri),
      const SizedBox(width: 10),
      tile(Icons.chat_outlined, 'WhatsApp', 'Live chat', Kv.successSoft, Kv.success, storeWhatsAppUri),
      const SizedBox(width: 10),
      tile(Icons.mail_outline_rounded, 'Email', 'Within 24 h', Kv.goldSoft, Kv.gold, storeEmailUri),
    ]);
  }
}

/// The showroom: address, hours, phone and email.
class StoreCard extends StatelessWidget {
  const StoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String title, String body, {String? uri}) => InkWell(
          onTap: uri == null ? null : () => openLink(uri),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 20, color: Kv.muted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Kv.muted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(fontSize: 14, height: 1.45, color: uri == null ? Kv.ink : Kv.blue)),
                ]),
              ),
            ]),
          ),
        );
    return KvCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(child: Text('KV Silver Zone, Ambattur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            StatusPill('Showroom', tone: PillTone.gold),
          ]),
        ),
        row(Icons.location_on_outlined, 'Address', storeAddress),
        row(Icons.schedule_rounded, 'Hours', 'Mon – Sat: 10:00 AM – 8:00 PM\nSunday: Closed'),
        row(Icons.call_outlined, 'Phone', storePhone, uri: storePhoneUri),
        row(Icons.mail_outline_rounded, 'Email', storeEmail, uri: storeEmailUri),
      ]),
    );
  }
}
