/// Form validation rules ported from kv-silver-zone/src/lib/validation.ts (zod).
///
/// Messages are copied verbatim from the web app so the two clients report the
/// same failure in the same words. `kv-api` performs almost no request
/// validation of its own (only the address endpoints check phone/pincode), so
/// these rules are the real gate on malformed input — keep them in sync with
/// the web's zod schemas, not with the server.
///
/// Every validator returns `null` when valid, or the user-facing message when
/// not, which is exactly the contract Flutter's `TextFormField.validator` wants.
library;

final _digits = RegExp(r'\D');
final _indianMobile = RegExp(r'^[6-9]\d{9}$');
final _sixDigitPin = RegExp(r'^\d{6}$');
final _email = RegExp(r"^[\w.!#$%&'*+/=?^`{|}~-]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$");

/// Strips non-digits, then drops a leading `91` country code or trunk `0` only
/// when that leaves exactly 10 digits — matches kv-api's `toIndianMobile`, so
/// `+91 98765 43210` and `09876543210` normalize but `0919876543210` stays invalid.
String normalizePhone(String value) {
  var d = value.replaceAll(_digits, '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return d;
}

String? validateEmail(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Email is required';
  if (!_email.hasMatch(v)) return 'Enter a valid email address';
  return null;
}

String? validateName(String? value) {
  final v = (value ?? '').trim();
  if (v.length < 2) return 'Please enter at least 2 characters';
  return null;
}

/// Signup/change-password strength rule. Length-only, minimum 6 — the web
/// enforces no complexity requirement and neither does the server.
String? validatePassword(String? value) {
  if ((value ?? '').length < 6) return 'Password must be at least 6 characters';
  return null;
}

/// Login deliberately does NOT use [validatePassword]: existing accounts may
/// predate the 6-character rule and must still be able to sign in.
String? validateLoginPassword(String? value) {
  if ((value ?? '').isEmpty) return 'Password is required';
  return null;
}

String? validateConfirmPassword(String? value, String password) {
  if ((value ?? '').isEmpty) return 'Please confirm your password';
  if (value != password) return 'Passwords do not match';
  return null;
}

String? validatePhone(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Phone number is required';
  if (!_indianMobile.hasMatch(normalizePhone(v))) {
    return 'Enter a valid 10-digit Indian mobile number';
  }
  return null;
}

/// Profile's phone field is optional — blank is accepted, but a non-blank value
/// must still be a valid Indian mobile.
String? validateOptionalPhone(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return null;
  return validatePhone(v);
}

String? validatePincode(String? value) {
  final v = (value ?? '').trim();
  if (!_sixDigitPin.hasMatch(v)) return 'Enter a valid 6-digit PIN code';
  return null;
}

String? validateLastName(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Last name is required';
  return null;
}

String? validateStreetAddress(String? value) {
  final v = (value ?? '').trim();
  if (v.length < 5) return 'Please enter a complete address';
  return null;
}

String? validateCity(String? value) {
  final v = (value ?? '').trim();
  if (v.length < 2) return 'City is required';
  return null;
}

String? validateState(String? value) {
  final v = (value ?? '').trim();
  if (v.length < 2) return 'State is required';
  return null;
}

String? validateOtpCode(String? value) {
  final v = (value ?? '').trim();
  if (v.length != 6) return 'Enter the 6-digit code';
  return null;
}
