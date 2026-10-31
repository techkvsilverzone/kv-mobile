import 'package:url_launcher/url_launcher.dart';

/// The store's contact links, as the web's tel:/mailto:/wa.me hrefs.
const storePhoneUri = 'tel:+918825649680';
const storeEmailUri = 'mailto:kvszchennai@gmail.com';
const storeWhatsAppUri = 'https://wa.me/918825649680';

/// tel: for a phone-looking value, mailto: for an email, else the value itself.
String hrefFor(String value) {
  if (value.contains('://')) return value;
  if (value.contains('@')) return 'mailto:$value';
  final digits = value.replaceAll(RegExp(r'[^\d+]'), '');
  if (RegExp(r'^\+?\d{10,13}$').hasMatch(digits)) {
    return 'tel:${digits.startsWith('+') ? digits : '+$digits'}';
  }
  return value;
}

/// Opens in the phone's dialer / mail app / browser. False when nothing can.
Future<bool> openLink(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
