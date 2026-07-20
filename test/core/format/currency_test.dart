import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/format/currency.dart';

void main() {
  group('formatInr', () {
    test('prefixes the rupee sign with no space and no decimals', () {
      expect(formatInr(1250), '₹1,250');
    });

    test('uses Indian lakh/crore grouping, not thousands grouping', () {
      // The main gotcha: en_IN groups 3 digits then 2.
      expect(formatInr(100000), '₹1,00,000');
      expect(formatInr(1234567), '₹12,34,567');
      expect(formatInr(10000000), '₹1,00,00,000');
    });

    test('rounds away fractional rupees', () {
      expect(formatInr(2249.6), '₹2,250');
      expect(formatInr(0), '₹0');
    });

    test('formats a per-gram rate with the suffix outside the number', () {
      expect(formatRatePerGram(92), '₹92/g');
    });
  });
}
