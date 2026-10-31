import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/savings/application/installment_payer.dart';
import 'package:kv_silver_mobile/features/savings/data/savings_models.dart';
import 'package:kv_silver_mobile/features/savings/presentation/savings_scheme_screen.dart';

Map<String, dynamic> _pay(double amount, String paidAt,
        {double w = 0, double rate = 0, double dw = 0, String? rzp}) =>
    {
      'month': 0, 'amount': amount, 'paidAt': paidAt, 'materialRate': rate, 'materialWeight': w,
      'devidentAmount': 0, 'devidentMaterialRate': 0, 'devidentMaterialWeight': dw,
      'razorpayPaymentId': rzp,
    };

SavingsEnrollment _scheme({String status = 'Active', int duration = 11, String? metal = 'SILVER',
        List<Map<String, dynamic>> payments = const [], String? maturity}) =>
    SavingsEnrollment.fromJson({
      '_id': 's1', 'userId': 'u1', 'schemeType': 'SILVER_11_1', 'metal': metal,
      'monthlyAmount': 1000, 'duration': duration, 'startDate': '2026-01-01', 'status': status,
      'totalPaid': 2000, 'bonusAmount': 0, 'payments': payments, 'maturityDate': maturity,
    });

void main() {
  test('summarizeScheme numbers real installments oldest-first and skips the bonus row', () {
    final s = summarizeScheme(_scheme(payments: [
      _pay(1000, '2026-02-05', w: 10.1234),
      _pay(0, '2026-03-01', dw: 1.0006),
      _pay(1000, '2026-01-05', w: 10),
    ]));
    expect(s.installments.map((i) => i.monthNumber), [1, 2, null]);
    expect(s.paidMonths, 2);
    expect(s.pendingMonths, 9);
    expect(s.nextMonth, 3);
    expect(s.progressPercent, 18);
    expect(s.totalGrams, 21.124);
    expect(s.hasGrams, isTrue);
  });

  test('inactive schemes have nothing pending and no next month', () {
    final s = summarizeScheme(_scheme(status: 'Completed', metal: null));
    expect(s.pendingMonths, 0);
    expect(s.nextMonth, isNull);
    expect(s.hasGrams, isFalse);
  });

  test('projection: bonus months, hamper counts as one month, flexible has none', () {
    SchemePlan plan(Map<String, dynamic> extra) => SchemePlan.fromJson(
        {'_id': 'p', 'type': 'T', 'name': 'P', 'durationMonths': 11, 'bonusMonths': 1, ...extra});
    expect(projectSavings(plan({}), 1000), (totalPaid: 11000.0, bonusAmount: 1000.0, totalValue: 12000.0));
    expect(projectSavings(plan({'bonusMonths': 0, 'hamper': {'gifts': []}}), 500)?.bonusAmount, 500);
    expect(projectSavings(plan({'paymentMode': 'FLEXIBLE'}), 1000), isNull);
    expect(projectSavings(plan({}), null), isNull);
  });

  test('canPay: fixed until all real months paid; flexible until maturity', () {
    final paid = [for (var i = 0; i < 11; i++) _pay(1000, '2026-${(i % 12) + 1}-01')];
    expect(canPayScheme(_scheme(payments: paid), isFlexible: false), isFalse);
    expect(canPayScheme(_scheme(), isFlexible: false), isTrue);
    expect(canPayScheme(_scheme(status: 'Dropped'), isFlexible: false), isFalse);
    final s = _scheme(maturity: '2026-06-01T00:00:00Z');
    expect(canPayScheme(s, isFlexible: true, now: DateTime.utc(2026, 5, 31)), isTrue);
    expect(canPayScheme(s, isFlexible: true, now: DateTime.utc(2026, 6, 2)), isFalse);
  });

  test('success message matches the credited row by Razorpay id', () {
    final before = _scheme();
    final after = _scheme(payments: [
      _pay(1000, '2026-01-05', w: 10, rate: 100),
      _pay(1000, '2026-02-05', w: 9.5, rate: 105.26, rzp: 'pay_2'),
      _pay(0, '2026-02-05', dw: 1),
    ]);
    final (title, body) = installmentSuccessMessage(
        before: before, after: after, isFlexible: false, paidAmount: 1000, razorpayPaymentId: 'pay_2');
    expect(title, 'Month 2 of 11 paid');
    expect(body, '₹1,000 received. 9.500g added at ₹105/g · total now 20.500g. 9 months pending.');

    final (t2, b2) = installmentSuccessMessage(
        before: before, after: after, isFlexible: true, paidAmount: 1250.5, razorpayPaymentId: 'pay_2');
    expect(t2, 'Payment Successful!');
    expect(b2, "₹1,250.5 recorded on your passbook. — 9.500g Silver credited at today's rate of ₹105/g.");
  });
}
