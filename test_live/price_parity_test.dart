// Shown price == charged price for every product. Inputs captured from production:
// products.json (GET /products) and charged.json (server computeCheckout per product).
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/pricing/pricing.dart';
import 'package:kv_silver_mobile/features/catalog/data/models/product.dart';

void main() {
  test('the app prices every product exactly as checkout charges it', () {
    final products = (jsonDecode(File('/private/tmp/claude-501/-Users-vino-Documents-Workspace-Projects-KraftLabs-kvsz/7eec0128-a9f7-4caf-a9b1-b06dadb8c10b/scratchpad/products.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final charged = (jsonDecode(File('/private/tmp/claude-501/-Users-vino-Documents-Workspace-Projects-KraftLabs-kvsz/7eec0128-a9f7-4caf-a9b1-b06dadb8c10b/scratchpad/charged.json').readAsStringSync()) as Map).cast<String, dynamic>();
    final mismatches = <String>[];
    for (final j in products) {
      final p = Product.fromJson(j);
      final shown = computeProductPricing(p.toPricingInput(), const []).preGstPrice;
      final charge = (charged[p.id] as num).toDouble();
      if ((shown - charge).abs() > 0.005) mismatches.add('${p.name}: app $shown vs charged $charge');
      // ignore: avoid_print
      print('${p.id.padLeft(2)} ${p.name.padRight(28)} app=$shown charged=$charge');
    }
    expect(mismatches, isEmpty);
  });
}
