// Extra sample data for the savings / rates / dashboard screenshots.
import 'package:kv_silver_mobile/core/pricing/pricing.dart';
import 'package:kv_silver_mobile/features/auth/data/address_repository.dart';
import 'package:kv_silver_mobile/features/auth/data/models/address.dart';
import 'package:kv_silver_mobile/features/auth/data/models/user.dart';
import 'package:kv_silver_mobile/features/savings/data/savings_models.dart';
import 'fixtures.dart';

const sampleUser = User(id: 'u1', name: 'Vinoth Kumar', email: 'vinoth@example.com', role: 'customer', phone: '9876543210');

String _day(int back) => DateTime(2026, 10, 31).subtract(Duration(days: back)).toIso8601String().substring(0, 10);

/// 30 days of gently drifting rates, newest first (as the API returns them).
final silverHistory30 = [
  for (var d = 0; d < 30; d++)
    MetalRate(id: 's$d', date: _day(d), ratePerGram: 112 - d * 0.35 + (d % 5 == 0 ? 1.2 : 0) - (d % 7) * 0.2, ratePerKg: 0, purity: '999'),
];
final goldHistory30 = [
  for (var d = 0; d < 30; d++)
    MetalRate(id: 'g$d', date: _day(d), ratePerGram: 7350 - d * 9 + (d % 4) * 14, ratePerKg: 0, purity: '916'),
];
final silverToday = [MetalRate(id: 's', date: _day(0), ratePerGram: silverHistory30[0].ratePerGram, ratePerKg: silverHistory30[0].ratePerGram * 1000, purity: '999')];
final goldToday = [MetalRate(id: 'g', date: _day(0), ratePerGram: goldHistory30[0].ratePerGram, ratePerKg: goldHistory30[0].ratePerGram * 1000, purity: '916')];

SavingsEnrollment goldScheme() => SavingsEnrollment.fromJson({
      '_id': 'sch2', 'userId': 'u1', 'passbookNumber': 'GLD-2526-0000031', 'schemeType': 'GOLD_11_1', 'metal': 'GOLD',
      'planName': 'Gold Purchase Plan', 'monthlyAmount': 5000, 'duration': 11, 'startDate': '2026-09-02',
      'status': 'Active', 'totalPaid': 10000, 'bonusAmount': 0, 'maturityDate': '2027-08-02T00:00:00Z',
      'payments': [
        {'id': 'R-2001', 'month': 1, 'amount': 5000, 'paidAt': '2026-09-02T10:00:00Z', 'materialRate': 7210, 'materialWeight': 0.693, 'method': 'ONLINE'},
        {'id': 'R-2002', 'month': 2, 'amount': 5000, 'paidAt': '2026-10-04T10:00:00Z', 'materialRate': 7330, 'materialWeight': 0.682, 'method': 'CASH'},
      ],
    });

SavingsEnrollment smartScheme() => SavingsEnrollment.fromJson({
      '_id': 'sch3', 'userId': 'u1', 'passbookNumber': 'SMT-2526-0000007', 'schemeType': 'SILVER_SMART', 'metal': 'SILVER',
      'planName': 'KV Smart Purchase Plan', 'monthlyAmount': 500, 'duration': 11, 'startDate': '2026-07-12',
      'status': 'Active', 'totalPaid': 4750, 'bonusAmount': 0, 'maturityDate': '2027-06-12T00:00:00Z',
      'payments': [
        for (final (i, (amt, date, rate)) in const [
          (1500, '2026-07-12', 101.5), (750, '2026-08-03', 104.0), (2000, '2026-09-18', 107.2), (500, '2026-10-21', 111.4),
        ].indexed)
          {'id': 'R-30${i + 1}', 'month': 0, 'amount': amt, 'paidAt': '${date}T09:00:00Z', 'materialRate': rate,
            'materialWeight': double.parse((amt / rate).toStringAsFixed(3)), 'method': i == 1 ? 'CASH' : 'ONLINE'},
      ],
    });

/// The fixture scheme with receipt numbers (sampleScheme's rows have none).
SavingsEnrollment silverScheme() {
  final s = sampleScheme();
  return SavingsEnrollment.fromJson({
    '_id': s.id, 'userId': 'u1', 'passbookNumber': s.passbookNumber, 'schemeType': s.schemeType, 'metal': s.metal,
    'planName': s.planName, 'monthlyAmount': s.monthlyAmount, 'duration': s.duration, 'startDate': s.startDate,
    'status': s.status, 'totalPaid': s.totalPaid, 'bonusAmount': 0, 'maturityDate': s.maturityDate,
    'payments': [
      for (final (i, p) in s.payments.indexed)
        {'id': 'R-10${i + 1}', 'month': p.month, 'amount': p.amount, 'paidAt': '2026-${(6 + i).toString().padLeft(2, '0')}-05T10:00:00Z',
          'materialRate': p.materialRate, 'materialWeight': p.materialWeight, 'method': i == 2 ? 'CASH' : 'ONLINE'},
    ],
  });
}

class NoAddressRepo implements AddressRepository {
  @override
  Future<List<Address>> list() async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
