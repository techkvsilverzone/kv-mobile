/// Savings-scheme models, hand-ported from kv-ui/src/services/{savings,schemePlan}.ts.
library;

double _d(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);
double? _dn(dynamic v) => v == null ? null : _d(v);
int _i(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
String? _s(dynamic v) => v?.toString();
Map<String, dynamic> _m(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};
List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

/// Unwraps `{status, data}` when present (the scheme-plan endpoints use it).
dynamic unwrapData(dynamic raw) => raw is Map && raw.containsKey('data') ? raw['data'] : raw;

/// Display names for scheme types without a plan name (CustomerDashboard).
const schemeTypeLabels = {
  'GOLD_11_1': 'Gold Purchase Plan',
  'SILVER_11_1': 'Silver Purchase Plan',
  'DIWALI': 'Diwali Scheme',
  'GOLD_INCOME': 'Gold Income Scheme',
  'SILVER_DEPOSIT': 'Silver Deposit Scheme',
  'SILVER_SMART': 'KV Smart Purchase Plan',
};

class SchemeHamper {
  const SchemeHamper({this.goldCoinPurity, this.silverCoinGrams, this.giftsValue, this.gifts = const []});
  final String? goldCoinPurity;
  final double? silverCoinGrams;
  final double? giftsValue;
  final List<String> gifts;

  factory SchemeHamper.fromJson(Map<String, dynamic> j) => SchemeHamper(
        goldCoinPurity: _s(j['goldCoinPurity']),
        silverCoinGrams: _dn(j['silverCoinGrams']),
        giftsValue: _dn(j['giftsValue']),
        gifts: _strings(j['gifts']),
      );
}

class SchemePlan {
  const SchemePlan({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.metal,
    required this.durationMonths,
    required this.bonusMonths,
    required this.isFlexible,
    required this.monthlyAmounts,
    this.minPaymentAmount,
    this.hamper,
  });

  final String id;
  final String type;
  final String name;
  final String? description;

  /// 'GOLD' | 'SILVER'; null for DIWALI.
  final String? metal;
  final int durationMonths;
  final int bonusMonths;

  /// paymentMode == 'FLEXIBLE' (KV Smart Purchase Plan).
  final bool isFlexible;
  final List<double> monthlyAmounts;
  final double? minPaymentAmount;
  final SchemeHamper? hamper;

  factory SchemePlan.fromJson(Map<String, dynamic> j) => SchemePlan(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        description: _s(j['description']),
        metal: _s(j['metal']),
        durationMonths: _i(j['durationMonths']),
        bonusMonths: _i(j['bonusMonths']),
        isFlexible: j['paymentMode'] == 'FLEXIBLE',
        monthlyAmounts: j['monthlyAmounts'] is List
            ? (j['monthlyAmounts'] as List).map(_d).toList()
            : const [],
        minPaymentAmount: _dn(j['minPaymentAmount']),
        hamper: j['hamper'] is Map ? SchemeHamper.fromJson(_m(j['hamper'])) : null,
      );
}

class SavingsPayment {
  const SavingsPayment({
    this.id,
    required this.month,
    required this.amount,
    required this.paidAt,
    required this.materialRate,
    required this.materialWeight,
    required this.devidentAmount,
    required this.devidentMaterialRate,
    required this.devidentMaterialWeight,
    this.method,
    this.razorpayPaymentId,
    this.dueMonthKey,
  });

  /// Receipt number shown to the customer.
  final String? id;
  final int month;

  /// Cash collected; 0 on the auto-credited bonus row.
  final double amount;
  final String paidAt;
  final double materialRate;
  final double materialWeight;
  final double devidentAmount;
  final double devidentMaterialRate;
  final double devidentMaterialWeight;

  /// 'ONLINE' | 'CASH'.
  final String? method;
  final String? razorpayPaymentId;
  final String? dueMonthKey;

  factory SavingsPayment.fromJson(Map<String, dynamic> j) => SavingsPayment(
        id: _s(j['id'] ?? j['_id']),
        month: _i(j['month']),
        amount: _d(j['amount']),
        paidAt: (j['paidAt'] ?? '').toString(),
        materialRate: _d(j['materialRate']),
        materialWeight: _d(j['materialWeight']),
        devidentAmount: _d(j['devidentAmount']),
        devidentMaterialRate: _d(j['devidentMaterialRate']),
        devidentMaterialWeight: _d(j['devidentMaterialWeight']),
        method: _s(j['method']),
        razorpayPaymentId: _s(j['razorpayPaymentId']),
        dueMonthKey: _s(j['dueMonthKey']),
      );
}

class MaturityBenefits {
  const MaturityBenefits({
    this.goldCoinValue,
    this.goldGrams,
    this.goldRatePerGram,
    this.silverGrams,
    this.silverValue,
    this.silverRatePerGram,
    this.giftsValue,
    this.gifts = const [],
    this.computedAt,
  });

  final double? goldCoinValue, goldGrams, goldRatePerGram;
  final double? silverGrams, silverValue, silverRatePerGram;
  final double? giftsValue;
  final List<String> gifts;

  /// When the DIWALI redemption payout was computed; unset until then.
  final String? computedAt;

  factory MaturityBenefits.fromJson(Map<String, dynamic> j) => MaturityBenefits(
        goldCoinValue: _dn(j['goldCoinValue']),
        goldGrams: _dn(j['goldGrams']),
        goldRatePerGram: _dn(j['goldRatePerGram']),
        silverGrams: _dn(j['silverGrams']),
        silverValue: _dn(j['silverValue']),
        silverRatePerGram: _dn(j['silverRatePerGram']),
        giftsValue: _dn(j['giftsValue']),
        gifts: _strings(j['gifts']),
        computedAt: _s(j['computedAt']),
      );
}

/// Early-exit forfeit / redeemable split, set once a scheme is cancelled.
class SavingsCancellation {
  const SavingsCancellation({
    required this.cancelledAt,
    required this.amountPaidAtCancellation,
    required this.penaltyPercent,
    required this.penaltyAmount,
    required this.giftsValueDeducted,
    required this.netRedeemable,
    this.note,
  });

  final String cancelledAt;
  final double amountPaidAtCancellation, penaltyPercent, penaltyAmount;
  final double giftsValueDeducted, netRedeemable;
  final String? note;

  factory SavingsCancellation.fromJson(Map<String, dynamic> j) => SavingsCancellation(
        cancelledAt: (j['cancelledAt'] ?? '').toString(),
        amountPaidAtCancellation: _d(j['amountPaidAtCancellation']),
        penaltyPercent: _d(j['penaltyPercent']),
        penaltyAmount: _d(j['penaltyAmount']),
        giftsValueDeducted: _d(j['giftsValueDeducted']),
        netRedeemable: _d(j['netRedeemable']),
        note: _s(j['note']),
      );
}

/// The scheme's owner when the server populates it (passbook lookup); else just an id.
class SchemeOwner {
  const SchemeOwner({required this.id, this.name, this.email, this.phone});
  final String id;
  final String? name, email, phone;
}

class SavingsEnrollment {
  const SavingsEnrollment({
    required this.id,
    required this.owner,
    this.passbookNumber,
    required this.schemeType,
    this.metal,
    this.planName,
    required this.monthlyAmount,
    required this.duration,
    required this.startDate,
    required this.status,
    required this.totalPaid,
    required this.bonusAmount,
    this.payments = const [],
    this.maturityBenefits,
    this.cancellation,
    this.maturityDate,
  });

  final String id;
  final SchemeOwner owner;

  /// Unset until the first payment is recorded.
  final String? passbookNumber;
  final String schemeType;
  final String? metal;
  final String? planName;
  final double monthlyAmount;
  final int duration;
  final String startDate;

  /// 'Active' | 'Completed' | 'Cancelled' | 'Dropped'.
  final String status;
  final double totalPaid;
  final double bonusAmount;
  final List<SavingsPayment> payments;
  final MaturityBenefits? maturityBenefits;
  final SavingsCancellation? cancellation;

  /// Computed server-side at read time; a late payment pushes it out.
  final String? maturityDate;

  bool get isActive => status == 'Active';
  bool get isGold => metal == 'GOLD';
  String get displayName => planName ?? schemeTypeLabels[schemeType] ?? schemeType;

  factory SavingsEnrollment.fromJson(Map<String, dynamic> j) {
    final u = j['userId'];
    final owner = u is Map
        ? SchemeOwner(
            id: (u['_id'] ?? u['id'] ?? '').toString(),
            name: _s(u['name']),
            email: _s(u['email']),
            phone: _s(u['phone']))
        : SchemeOwner(id: (u ?? '').toString());
    return SavingsEnrollment(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      owner: owner,
      passbookNumber: _s(j['passbookNumber']),
      schemeType: (j['schemeType'] ?? '').toString(),
      metal: _s(j['metal']),
      planName: _s(j['planName']),
      monthlyAmount: _d(j['monthlyAmount']),
      duration: _i(j['duration']),
      startDate: (j['startDate'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      totalPaid: _d(j['totalPaid']),
      bonusAmount: _d(j['bonusAmount']),
      payments: j['payments'] is List
          ? (j['payments'] as List).whereType<Map>().map((e) => SavingsPayment.fromJson(_m(e))).toList()
          : const [],
      maturityBenefits:
          j['maturityBenefits'] is Map ? MaturityBenefits.fromJson(_m(j['maturityBenefits'])) : null,
      cancellation: j['cancellation'] is Map ? SavingsCancellation.fromJson(_m(j['cancellation'])) : null,
      maturityDate: _s(j['maturityDate']),
    );
  }
}

/// One row of the month-by-month picture (kv-ui lib/savingsSummary.ts).
class Installment {
  const Installment({required this.monthNumber, required this.payment, required this.grams});

  /// 1-based month for a collected installment; null for the auto-credited bonus row.
  final int? monthNumber;
  final SavingsPayment payment;

  /// Grams credited, including any bonus (devident) weight.
  final double grams;
}

class SchemeSummary {
  const SchemeSummary({
    required this.totalMonths,
    required this.paidMonths,
    required this.pendingMonths,
    required this.nextMonth,
    required this.progressPercent,
    required this.totalPaid,
    required this.totalGrams,
    required this.hasGrams,
    required this.installments,
  });

  final int totalMonths, paidMonths, pendingMonths;
  final int? nextMonth;
  final int progressPercent;
  final double totalPaid, totalGrams;
  final bool hasGrams;

  /// Oldest first.
  final List<Installment> installments;
}

/// `summarizeScheme`: meaningful for FIXED plans only.
SchemeSummary summarizeScheme(SavingsEnrollment s) {
  int ms(String iso) => DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? 0;
  // Stable, like JS Array.sort: equal paidAt keeps server order (Dart's sort isn't stable).
  final indexed = s.payments.indexed.toList()
    ..sort((a, b) {
      final c = ms(a.$2.paidAt).compareTo(ms(b.$2.paidAt));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  final sorted = [for (final (_, p) in indexed) p];
  var counter = 0;
  final installments = [
    for (final p in sorted)
      Installment(
        monthNumber: p.amount > 0 ? ++counter : null,
        payment: p,
        grams: p.materialWeight + p.devidentMaterialWeight,
      ),
  ];
  final pending = s.isActive ? (s.duration - counter).clamp(0, 1 << 30) : 0;
  return SchemeSummary(
    totalMonths: s.duration,
    paidMonths: counter,
    pendingMonths: pending,
    nextMonth: s.isActive && counter < s.duration ? counter + 1 : null,
    progressPercent: s.duration > 0 ? ((counter / s.duration) * 100).round().clamp(0, 100) : 0,
    totalPaid: s.totalPaid,
    totalGrams: (installments.fold(0.0, (sum, i) => sum + i.grams) * 1000).round() / 1000,
    hasGrams: s.metal != null && s.metal!.isNotEmpty,
    installments: installments,
  );
}
