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

double resolveChargeAmount(ProductCharge? charge, double base) {
  if (charge == null || charge.value < 0) return 0;
  return charge.type == ChargeType.amount ? charge.value : (base * charge.value) / 100;
}

class ProductPricingInput {
  const ProductPricingInput({
    required this.price,
    required this.isFixedPrice,
    this.weight,
    this.weightInGrams,
    this.purity,
    this.makingCharge,
    this.wastage,
  });

  final double price;
  final bool isFixedPrice;
  final String? weight;
  final double? weightInGrams;
  final String? purity;
  final ProductCharge? makingCharge;
  final ProductCharge? wastage;
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
  final bool computed;
  final double? ratePerGram;
  final double? grams;
  final double? metalValue;
  final double? makingCharge;
  final double? wastage;
  final double preGstPrice;
}

ProductPriceBreakdown computeProductPricing(
  ProductPricingInput product,
  List<MetalRate> rates, {
  double? gramsOverride,
}) {
  final fallback = ProductPriceBreakdown(
    isFixedPrice: product.isFixedPrice,
    computed: false,
    ratePerGram: null,
    grams: null,
    metalValue: null,
    makingCharge: null,
    wastage: null,
    preGstPrice: product.price,
  );

  if (product.isFixedPrice) return fallback;

  final hasConfiguredCharge = product.makingCharge != null || product.wastage != null;
  final grams = gramsOverride ?? product.weightInGrams ?? parseGrams(product.weight);
  final ratePerGram = matchSilverRate(rates, product.purity)?.ratePerGram;

  if (grams == null || grams <= 0 || ratePerGram == null || !hasConfiguredCharge) {
    return fallback;
  }

  final metalValue = grams * ratePerGram;
  final makingCharge = resolveChargeAmount(product.makingCharge, metalValue);
  final wastage = resolveChargeAmount(product.wastage, metalValue);

  return ProductPriceBreakdown(
    isFixedPrice: false,
    computed: true,
    ratePerGram: ratePerGram,
    grams: grams,
    metalValue: metalValue,
    makingCharge: makingCharge,
    wastage: wastage,
    preGstPrice: metalValue + makingCharge + wastage,
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
