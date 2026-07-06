// test/core/pricing/pricing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/pricing/pricing.dart';

MetalRate _rate({String purity = '925', double ratePerGram = 90}) => MetalRate(
      id: '1',
      date: '2026-06-16',
      ratePerGram: ratePerGram,
      ratePerKg: ratePerGram * 1000,
      purity: purity,
    );

void main() {
  group('parseGrams', () {
    test('extracts the numeric grams from a free-text weight', () {
      expect(parseGrams('10.5 g'), 10.5);
      expect(parseGrams('20g'), 20);
    });

    test('returns null for missing or non-positive weights', () {
      expect(parseGrams(null), isNull);
      expect(parseGrams('abc'), isNull);
      expect(parseGrams('0 g'), isNull);
    });
  });

  group('matchSilverRate', () {
    test('matches the rate whose purity equals the product purity', () {
      final rates = [_rate(purity: '999', ratePerGram: 100), _rate(purity: '925', ratePerGram: 90)];
      expect(matchSilverRate(rates, '925')?.ratePerGram, 90);
      expect(matchSilverRate(rates, '92.5%')?.ratePerGram, 90);
    });

    test('falls back to the first rate when purity does not match', () {
      final rates = [_rate(purity: '999', ratePerGram: 100)];
      expect(matchSilverRate(rates, '800')?.ratePerGram, 100);
    });

    test('returns null when there are no rates', () {
      expect(matchSilverRate([], '925'), isNull);
    });
  });

  group('resolveChargeAmount', () {
    test('computes a percentage of the base', () {
      expect(resolveChargeAmount(const ProductCharge(type: ChargeType.percentage, value: 12), 1000), 120);
    });

    test('returns a flat amount as-is', () {
      expect(resolveChargeAmount(const ProductCharge(type: ChargeType.amount, value: 250), 1000), 250);
    });

    test('treats missing / invalid charges as zero', () {
      expect(resolveChargeAmount(null, 1000), 0);
      expect(resolveChargeAmount(const ProductCharge(type: ChargeType.amount, value: -5), 1000), 0);
    });

    test('treats a non-finite charge value as zero', () {
      expect(resolveChargeAmount(const ProductCharge(type: ChargeType.amount, value: double.nan), 1000), 0);
    });
  });

  group('computeProductPricing', () {
    final rates = [_rate(purity: '925', ratePerGram: 90)];

    test('computes metal value + making + wastage for a dynamic product', () {
      final result = computeProductPricing(
        const ProductPricingInput(
          price: 0,
          isFixedPrice: false,
          weight: '10 g',
          weightInGrams: 10,
          purity: '925',
          makingCharge: ProductCharge(type: ChargeType.percentage, value: 12),
          wastage: ProductCharge(type: ChargeType.amount, value: 100),
        ),
        rates,
      );
      expect(result.computed, isTrue);
      expect(result.metalValue, 900);
      expect(result.makingCharge, 108);
      expect(result.wastage, 100);
      expect(result.preGstPrice, 1108);
    });

    test('uses a gram override (selected variant weight) over the product weight', () {
      final result = computeProductPricing(
        const ProductPricingInput(
          price: 0,
          isFixedPrice: false,
          weight: '10 g',
          weightInGrams: 10,
          purity: '925',
          makingCharge: ProductCharge(type: ChargeType.percentage, value: 0),
        ),
        rates,
        gramsOverride: 20,
      );
      expect(result.grams, 20);
      expect(result.preGstPrice, 1800);
    });

    test('keeps the listed price for a legacy product with rate + weight but no charges configured', () {
      final result = computeProductPricing(
        const ProductPricingInput(
          price: 2500,
          isFixedPrice: false,
          weight: '10 g',
          weightInGrams: 10,
          purity: '925',
        ),
        rates,
      );
      expect(result.computed, isFalse);
      expect(result.preGstPrice, 2500);
    });

    test('returns the flat price for a fixed-price product (no metal calc)', () {
      final result = computeProductPricing(
        const ProductPricingInput(
          price: 4999,
          isFixedPrice: true,
          weight: '10 g',
          weightInGrams: 10,
          purity: '925',
        ),
        rates,
      );
      expect(result.isFixedPrice, isTrue);
      expect(result.computed, isFalse);
      expect(result.preGstPrice, 4999);
    });

    test('keeps the listed price when the matched rate is exactly zero', () {
      final zeroRates = [_rate(purity: '925', ratePerGram: 0)];
      final result = computeProductPricing(
        const ProductPricingInput(
          price: 2500,
          isFixedPrice: false,
          weight: '10 g',
          weightInGrams: 10,
          purity: '925',
          makingCharge: ProductCharge(type: ChargeType.percentage, value: 12),
        ),
        zeroRates,
      );
      expect(result.computed, isFalse);
      expect(result.preGstPrice, 2500);
    });

    test('falls back to product.price when there is no rate or weight', () {
      expect(
        computeProductPricing(
          const ProductPricingInput(price: 1500, isFixedPrice: false, weight: '', purity: '925'),
          rates,
        ).preGstPrice,
        1500,
      );
      expect(
        computeProductPricing(
          const ProductPricingInput(price: 1500, isFixedPrice: false, weight: '10 g', purity: '925'),
          const [],
        ).computed,
        isFalse,
      );
    });
  });

  group('computeOrderSummary', () {
    test('applies discount first, then GST on the discounted subtotal, then delivery', () {
      final s = computeOrderSummary(
        const OrderSummaryInput(subtotal: 1000, discount: 100, gstPercent: 3, deliveryCharge: 150),
      );
      expect(s.discountedSubtotal, 900);
      expect(s.gst, 27);
      expect(s.deliveryCharge, 150);
      expect(s.total, 1077);
    });

    test('taxes only the taxable subtotal (gift vouchers excluded)', () {
      final s = computeOrderSummary(
        const OrderSummaryInput(subtotal: 1000, taxableSubtotal: 600, gstPercent: 3),
      );
      expect(s.gst, 18);
      expect(s.total, 1018);
    });

    test('clamps the discount to the subtotal', () {
      final s = computeOrderSummary(const OrderSummaryInput(subtotal: 500, discount: 999, gstPercent: 3));
      expect(s.discount, 500);
      expect(s.discountedSubtotal, 0);
      expect(s.gst, 0);
      expect(s.total, 0);
    });

    test('defaults discount and delivery to zero', () {
      final s = computeOrderSummary(const OrderSummaryInput(subtotal: 1000, gstPercent: 3));
      expect(s.total, 1030);
    });
  });
}
