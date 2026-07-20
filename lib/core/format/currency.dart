import 'package:intl/intl.dart';

/// Indian rupee formatting, matching the web app's `Intl.NumberFormat('en-IN',
/// {style:'currency', currency:'INR', maximumFractionDigits:0})` — which is
/// copy-pasted into ~15 files there and reproduced once here.
///
/// The `en_IN` locale is what produces lakh/crore grouping (3 digits then 2:
/// `₹1,00,000`, not `₹100,000`), so it must not be dropped.
final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String formatInr(num value) => _inr.format(value);

/// Per-gram metal rate, e.g. `₹92/g`. The web appends the suffix outside the
/// formatter, so the spacing matches.
String formatRatePerGram(num value) => '${formatInr(value)}/g';
