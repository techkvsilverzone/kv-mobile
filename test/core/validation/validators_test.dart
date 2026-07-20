import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/validation/validators.dart';

/// Messages are asserted literally: they must stay identical to the web app's
/// zod schemas (kv-silver-zone/src/lib/validation.ts) so both clients report the
/// same failure in the same words.
void main() {
  group('normalizePhone', () {
    test('strips spaces, dashes and a +91 country code', () {
      expect(normalizePhone('+91 98765 43210'), '9876543210');
      expect(normalizePhone('98765-43210'), '9876543210');
      expect(normalizePhone('9876543210'), '9876543210');
    });

    test('only strips a leading 91 when that leaves exactly 10 digits', () {
      // 13 digits — the web's length-12 guard does not fire, so this stays
      // invalid rather than being silently "fixed".
      expect(normalizePhone('0919876543210'), '0919876543210');
    });
  });

  group('validatePhone', () {
    test('accepts Indian mobiles starting 6-9, in any common format', () {
      for (final v in ['9876543210', '+91 98765 43210', '6123456789', '7000000000']) {
        expect(validatePhone(v), isNull, reason: v);
      }
    });

    test('rejects landlines, wrong lengths and 0-5 leading digits', () {
      for (final v in ['5876543210', '987654321', '98765432101', '0919876543210']) {
        expect(validatePhone(v), 'Enter a valid 10-digit Indian mobile number', reason: v);
      }
    });

    test('reports a blank number as required rather than invalid', () {
      expect(validatePhone(''), 'Phone number is required');
      expect(validatePhone(null), 'Phone number is required');
    });
  });

  group('validateOptionalPhone', () {
    test('accepts blank because the profile phone is optional', () {
      expect(validateOptionalPhone(''), isNull);
      expect(validateOptionalPhone(null), isNull);
    });

    test('still rejects a malformed non-blank number', () {
      expect(validateOptionalPhone('12345'), 'Enter a valid 10-digit Indian mobile number');
    });
  });

  group('validatePincode', () {
    test('accepts exactly six digits, including leading zeros', () {
      expect(validatePincode('641001'), isNull);
      expect(validatePincode('001001'), isNull);
    });

    test('rejects anything that is not six digits', () {
      for (final v in ['', '64100', '6410011', '6410a1', null]) {
        expect(validatePincode(v), 'Enter a valid 6-digit PIN code', reason: '$v');
      }
    });
  });

  group('validateEmail', () {
    test('accepts ordinary addresses', () {
      for (final v in ['a@b.co', 'asha.kumar+shop@example.co.in']) {
        expect(validateEmail(v), isNull, reason: v);
      }
    });

    test('distinguishes blank from malformed', () {
      expect(validateEmail(''), 'Email is required');
      expect(validateEmail('   '), 'Email is required');
      expect(validateEmail('not-an-email'), 'Enter a valid email address');
      expect(validateEmail('a@b'), 'Enter a valid email address');
    });
  });

  group('passwords', () {
    test('signup requires at least six characters', () {
      expect(validatePassword('secret'), isNull);
      expect(validatePassword('12345'), 'Password must be at least 6 characters');
    });

    test('login only requires non-empty, so legacy short passwords still work', () {
      expect(validateLoginPassword('abc'), isNull);
      expect(validateLoginPassword(''), 'Password is required');
    });

    test('confirmation must be present and matching', () {
      expect(validateConfirmPassword('secret', 'secret'), isNull);
      expect(validateConfirmPassword('', 'secret'), 'Please confirm your password');
      expect(validateConfirmPassword('other', 'secret'), 'Passwords do not match');
    });
  });

  group('name fields', () {
    test('first name needs two characters but last name only needs one', () {
      expect(validateName('Jo'), isNull);
      expect(validateName('J'), 'Please enter at least 2 characters');
      // Single-letter surnames are common in India; the web allows them.
      expect(validateLastName('K'), isNull);
      expect(validateLastName(''), 'Last name is required');
    });
  });

  group('address fields', () {
    test('street address needs five characters', () {
      expect(validateStreetAddress('12 MG Road'), isNull);
      expect(validateStreetAddress('12'), 'Please enter a complete address');
    });

    test('city and state need two', () {
      expect(validateCity('Erode'), isNull);
      expect(validateCity('E'), 'City is required');
      expect(validateState('TN'), isNull);
      expect(validateState('T'), 'State is required');
    });
  });

  group('validateOtpCode', () {
    test('requires exactly six characters', () {
      expect(validateOtpCode('123456'), isNull);
      expect(validateOtpCode('12345'), 'Enter the 6-digit code');
    });
  });
}
