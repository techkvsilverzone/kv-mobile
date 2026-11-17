/// Shared product price engine — ports kv-silver-zone/src/lib/pricing.ts to Dart
/// so the app's displayed prices match the website exactly. Display only: the
/// server re-prices authoritatively at checkout.
enum ChargeType { percentage, amount }

class ProductCharge {
  const ProductCharge({required this.type, required this.value});
  final ChargeType type;
  final double value;
}

class MetalRate {
  const MetalRate({
    required this.id,
    required this.date,
    required this.ratePerGram,
    required this.ratePerKg,
    required this.purity,
    this.updatedBy,
  });

  final String id;
  final String date;
  final double ratePerGram;
  final double ratePerKg;
  final String purity;
  final String? updatedBy;
}

double? parseGrams(String? weight) {
  if (weight == null) return null;
  final match = RegExp(r'[\d.]+').firstMatch(weight);
  if (match == null) return null;
  final grams = double.tryParse(match.group(0)!);
  return (grams != null && grams > 0) ? grams : null;
}

double? parsePurityFraction(String? purity) {
  if (purity == null) return null;
  final match = RegExp(r'[\d.]+').firstMatch(purity);
  if (match == null) return null;
  final n = double.tryParse(match.group(0)!);
  if (n == null || n <= 0) return null;
  return n > 100 ? n / 1000 : n / 100;
}

MetalRate? matchSilverRate(List<MetalRate> rates, String? purity) {
  if (rates.isEmpty) return null;
  final frac = parsePurityFraction(purity);
  for (final r in rates) {
    final rf = parsePurityFraction(r.purity);
    if (frac != null && rf != null && (rf - frac).abs() < 0.01) {
      return r;
    }
  }
  return rates.first;
}

/// Server `resolveChargeAmount`: a percentage of the metal value, or flat rupees.
double resolveChargeAmount(ProductCharge? charge, double base) {
  if (charge == null || !charge.value.isFinite || charge.value <= 0) return 0;
  return charge.type == ChargeType.amount ? charge.value : (base * charge.value) / 100;
}

double _round2(double v) => (v * 100).round() / 100;

class ProductPricingInput {
  const ProductPricingInput({
    required this.price,
    required this.isFixedPrice,
    this.weight,
    this.weightInGrams,
    this.purity,
    this.material,
    this.makingCharge,
    this.wastage,
    this.makingCharges,
    this.makingChargePercent,
    this.makingChargePerGram,
    this.serverRatePerGram,
  });

  /// The admin's listed price (the static fallback).
  final double price;
  final bool isFixedPrice;
  final String? weight;
  final double? weightInGrams;
  final String? purity;
  final String? material;
  final ProductCharge? makingCharge;
  final ProductCharge? wastage;

  /// Legacy making-charge fields; null means "not set".
  final double? makingCharges;
  final double? makingChargePercent;
  final double? makingChargePerGram;

  /// The rate the server priced this product with (`pricing.*` on the
  /// product response). Using them keeps the app's price equal to the charge.
  final double? serverRatePerGram;
}

class ProductPriceBreakdown {
  const ProductPriceBreakdown({
    required this.isFixedPrice,
    required this.computed,
    required this.ratePerGram,
    required this.grams,
    required this.metalValue,
    required this.makingCharge,
    required this.wastage,
    required this.preGstPrice,
  });

  final bool isFixedPrice;

  /// True when priced live from the metal rate ("live" basis on the server).
  final bool computed;
  final double? ratePerGram;
  final double? grams;
  final double? metalValue;
  final double? makingCharge;
  final double? wastage;
  final double preGstPrice;
}

/// A port of kv-api `PricingService.computeUnitPrice`, so what the app shows is what
/// checkout charges. Fixed-price → listed price. Otherwise live only when a rate, a
/// weight and some charge input (new `{type,value}` or a non-null legacy field) exist:
/// weight × rate + making + wastage. Anything else → the listed price.
/// [rates] (today's rates) is only a fallback when the product carries no server rate.
ProductPriceBreakdown computeProductPricing(
  ProductPricingInput product,
  List<MetalRate> rates, {
  double? gramsOverride,
}) {
  final listed = ProductPriceBreakdown(
    isFixedPrice: product.isFixedPrice,
    computed: false,
    ratePerGram: null,
    grams: null,
    metalValue: null,
    makingCharge: null,
    wastage: null,
    preGstPrice: _round2(product.price),
  );
  if (product.isFixedPrice) return listed;

  final grams = (gramsOverride != null && gramsOverride > 0)
      ? gramsOverride
      : (product.weightInGrams ?? parseGrams(product.weight) ?? 0);
  final rate = product.serverRatePerGram ?? matchSilverRate(rates, product.purity)?.ratePerGram;
  final hasNewCharge = product.makingCharge != null || product.wastage != null;
  final hasLegacy =
      product.makingChargePerGram != null || product.makingChargePercent != null || product.makingCharges != null;

  if (rate == null || rate <= 0 || grams <= 0 || !(hasNewCharge || hasLegacy)) return listed;

  final metalValue = grams * rate;
  final double making;
  if (product.makingCharge != null) {
    making = resolveChargeAmount(product.makingCharge, metalValue);
  } else if (product.makingChargePerGram != null) {
    making = product.makingChargePerGram! * grams;
  } else if (product.makingChargePercent != null) {
    making = metalValue * product.makingChargePercent! / 100;
  } else {
    making = product.makingCharges ?? 0;
  }
  final wastage = resolveChargeAmount(product.wastage, metalValue);

  return ProductPriceBreakdown(
    isFixedPrice: false,
    computed: true,
    ratePerGram: rate,
    grams: grams,
    metalValue: _round2(metalValue),
    makingCharge: _round2(making),
    wastage: _round2(wastage),
    preGstPrice: _round2(metalValue + making + wastage),
  );
}

class OrderSummaryInput {
  const OrderSummaryInput({
    required this.subtotal,
    this.taxableSubtotal,
    this.discount = 0,
    required this.gstPercent,
    this.deliveryCharge = 0,
  });

  final double subtotal;
  final double? taxableSubtotal;
  final double discount;
  final double gstPercent;
  final double deliveryCharge;
}

class OrderSummary {
  const OrderSummary({
    required this.subtotal,
    required this.discount,
    required this.discountedSubtotal,
    required this.gst,
    required this.deliveryCharge,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double discountedSubtotal;
  final double gst;
  final double deliveryCharge;
  final double total;
}

OrderSummary computeOrderSummary(OrderSummaryInput input) {
  final taxable = input.taxableSubtotal ?? input.subtotal;
  final safeDiscount = input.discount.clamp(0, input.subtotal).toDouble();
  final discountedSubtotal = (input.subtotal - safeDiscount).clamp(0, double.infinity).toDouble();
  final taxableAfterDiscount = (taxable - safeDiscount).clamp(0, double.infinity).toDouble();
  final gst = (taxableAfterDiscount * input.gstPercent) / 100;

  return OrderSummary(
    subtotal: input.subtotal,
    discount: safeDiscount,
    discountedSubtotal: discountedSubtotal,
    gst: gst,
    deliveryCharge: input.deliveryCharge,
    total: discountedSubtotal + gst + input.deliveryCharge,
  );
}
