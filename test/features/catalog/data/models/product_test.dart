import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/pricing/pricing.dart';
import 'package:kv_silver_mobile/features/catalog/data/models/product.dart';

Map<String, dynamic> productJson([Map<String, dynamic> overrides = const {}]) => {
      '_id': 'p1',
      'name': 'Silver Anklet',
      'material': 'Silver',
      // The wire sends weight as a NUMBER, not a "12.5 g" string.
      'weight': 20,
      'weightInGrams': 20,
      'price': 2400,
      'listedPrice': 2000,
      'purity': '925',
      'isFixedPrice': false,
      'makingCharge': {'type': 'percentage', 'value': 10},
      'wastage': {'type': 'amount', 'value': 50},
      'stockAvailable': 3,
      'inStock': true,
      ...overrides,
    };

void main() {
  group('Product.fromJson', () {
    test('reads _id — products have no id alias', () {
      expect(Product.fromJson(productJson()).id, 'p1');
    });

    test('reads the category from `material`, since there is no category key', () {
      expect(Product.fromJson(productJson()).material, 'Silver');
    });

    test('keeps the server-computed price and the stored listedPrice apart', () {
      final p = Product.fromJson(productJson());
      expect(p.price, 2400);
      expect(p.listedPrice, 2000);
    });

    test('parses a numeric weight into grams', () {
      expect(Product.fromJson(productJson()).weightInGrams, 20);
    });

    test('falls back to `weight` when weightInGrams is absent', () {
      final json = productJson()..remove('weightInGrams');
      expect(Product.fromJson(json).weightInGrams, 20);
    });

    test('parses charge type enums', () {
      final p = Product.fromJson(productJson());
      expect(p.makingCharge?.type, ChargeType.percentage);
      expect(p.makingCharge?.value, 10);
      expect(p.wastage?.type, ChargeType.amount);
      expect(p.wastage?.value, 50);
    });

    test('handles charges arriving as explicit null, not just absent', () {
      // The server writes null for fixed-price products.
      final p = Product.fromJson(productJson({'makingCharge': null, 'wastage': null}));
      expect(p.makingCharge, isNull);
      expect(p.wastage, isNull);
    });

    test('treats an unknown charge type as percentage, as the server does', () {
      final p = Product.fromJson(productJson({
        'makingCharge': {'type': 'wibble', 'value': 5},
      }));
      expect(p.makingCharge?.type, ChargeType.percentage);
    });

    test('sorts images by sortOrder so the primary is first', () {
      final p = Product.fromJson(productJson({
        'images': [
          {'imageBase64': 'b', 'sortOrder': 2},
          {'imageBase64': 'a', 'sortOrder': 1},
        ],
      }));
      expect(p.primaryImage?.data, 'a');
    });

    test('recognises a remote URL stored in the imageBase64 field', () {
      final p = Product.fromJson(productJson({
        'images': [
          {'imageBase64': 'https://cdn.example.com/a.jpg', 'sortOrder': 0},
        ],
      }));
      expect(p.primaryImage?.isRemote, isTrue);
    });

    test('treats inline base64 as not remote', () {
      final p = Product.fromJson(productJson({
        'images': [
          {'imageBase64': 'data:image/png;base64,AAAA', 'sortOrder': 0},
        ],
      }));
      expect(p.primaryImage?.isRemote, isFalse);
    });

    test('drops variants that have neither a label nor a weight', () {
      final p = Product.fromJson(productJson({
        'variants': [
          {'label': 'M', 'weight': '20 g'},
          {'label': '', 'weight': ''},
        ],
      }));
      expect(p.variants.length, 1);
      expect(p.variants.single.label, 'M');
    });

    test('infers inStock from stockAvailable when the flag is missing', () {
      final json = productJson()..remove('inStock');
      expect(Product.fromJson(json).inStock, isTrue);

      final empty = productJson({'stockAvailable': 0})..remove('inStock');
      expect(Product.fromJson(empty).inStock, isFalse);
    });
  });

  group('toPricingInput', () {
    test('feeds the engine the listed price, not the server-computed one', () {
      // The engine recomputes from weight × rate; seeding it with the already
      // computed price would double-count when it falls back.
      final input = Product.fromJson(productJson()).toPricingInput();
      expect(input.price, 2000);
    });

    test('produces a computed breakdown when a matching rate exists', () {
      final product = Product.fromJson(productJson());
      final rates = [
        const MetalRate(
            id: 'r1', date: '2026-07-20', ratePerGram: 100, ratePerKg: 100000, purity: '925'),
      ];

      final pricing = computeProductPricing(product.toPricingInput(), rates);

      expect(pricing.computed, isTrue);
      expect(pricing.metalValue, 1850); // 20 g × ₹100 × 0.925
      expect(pricing.makingCharge, 185); // 10% of metal value
      expect(pricing.wastage, 50); // flat amount
      expect(pricing.preGstPrice, 2085);
    });

    test('a variant weight override changes the price', () {
      final product = Product.fromJson(productJson());
      final rates = [
        const MetalRate(
            id: 'r1', date: '2026-07-20', ratePerGram: 100, ratePerKg: 100000, purity: '925'),
      ];

      final pricing =
          computeProductPricing(product.toPricingInput(), rates, gramsOverride: 30);

      expect(pricing.grams, 30);
      expect(pricing.metalValue, 2775);
      expect(pricing.preGstPrice, 3102.5); // 2775 + 277.5 + 50
    });

    test('falls back to the listed price when no rates are available', () {
      final product = Product.fromJson(productJson());
      final pricing = computeProductPricing(product.toPricingInput(), const []);

      expect(pricing.computed, isFalse);
      expect(pricing.preGstPrice, 2000);
    });

    test('a product with no charges configured never gets a dynamic price', () {
      // Without this guard a product would price at bare metal value, below cost.
      final product =
          Product.fromJson(productJson({'makingCharge': null, 'wastage': null}));
      final rates = [
        const MetalRate(
            id: 'r1', date: '2026-07-20', ratePerGram: 100, ratePerKg: 100000, purity: '925'),
      ];

      final pricing = computeProductPricing(product.toPricingInput(), rates);

      expect(pricing.computed, isFalse);
      expect(pricing.preGstPrice, 2000);
    });
  });
}
