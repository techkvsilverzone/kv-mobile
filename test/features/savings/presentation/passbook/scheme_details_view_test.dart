import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/savings/data/savings_models.dart';
import 'package:kv_silver_mobile/features/savings/presentation/passbook/scheme_details_view.dart';

SavingsPayment pay(String id, String paidAt, double rate, double weight, {String method = 'ONLINE'}) =>
    SavingsPayment(
      id: id,
      month: 0,
      amount: 1000,
      paidAt: paidAt,
      materialRate: rate,
      materialWeight: weight,
      devidentAmount: 0,
      devidentMaterialRate: 0,
      devidentMaterialWeight: 0,
      method: method,
    );

SavingsEnrollment makeScheme(
        {String schemeType = 'SILVER_11_1', String? metal = 'SILVER', String status = 'Active'}) =>
    SavingsEnrollment(
      id: 's1',
      owner: const SchemeOwner(id: 'u1'),
      passbookNumber: 'SLV-0007',
      schemeType: schemeType,
      metal: metal,
      planName: 'Silver 11+1',
      monthlyAmount: 1000,
      duration: 11,
      startDate: '2026-01-05T00:00:00Z',
      maturityDate: '2026-12-05T00:00:00Z',
      status: status,
      totalPaid: 3000,
      bonusAmount: 1000,
      payments: [
        pay('101', '2026-01-05T00:00:00Z', 250, 4),
        pay('102', '2026-02-05T00:00:00Z', 240, 4.167, method: 'CASH'),
        pay('103', '2026-03-05T00:00:00Z', 260, 3.846),
      ],
    );

Future<void> pumpView(WidgetTester tester, Widget view) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: view))),
  ));
}

void main() {
  testWidgets('shows the summary the business asked for: paid, grams, paid and pending months',
      (tester) async {
    await pumpView(tester, SchemeDetailsView(scheme: makeScheme(), userName: 'Vino'));

    expect(find.text('₹3,000'), findsOneWidget);
    expect(find.text('12.013 g silver'), findsOneWidget);
    expect(find.text('3 of 11 months paid'), findsOneWidget);
    expect(find.text('8 to go'), findsOneWidget);
    expect(find.bySemanticsLabel('27% complete, 3 of 11 paid'), findsOneWidget);
  });

  testWidgets('lists month-wise history newest first with rate, amount, grams, mode and receipt number',
      (tester) async {
    await pumpView(tester, SchemeDetailsView(scheme: makeScheme()));

    final ys = [
      for (final m in ['Month 4', 'Month 3', 'Month 2', 'Month 1']) tester.getTopLeft(find.text(m)).dy
    ];
    expect(ys[0] < ys[1] && ys[1] < ys[2] && ys[2] < ys[3], isTrue);
    expect(find.text('Due'), findsOneWidget); // the next month, not yet paid

    final month2 = find.byKey(const ValueKey('installment-102'));
    Finder inCard(Finder f) => find.descendant(of: month2, matching: f);
    expect(inCard(find.text('Month 2')), findsOneWidget);
    expect(inCard(find.text('₹240/g')), findsOneWidget);
    expect(inCard(find.text('4.167 g')), findsOneWidget);
    expect(inCard(find.text('Paid in store')), findsOneWidget);
    expect(inCard(find.text('Receipt 102')), findsOneWidget);
    expect(inCard(find.byTooltip('Download receipt for Month 2')), findsOneWidget);
  });

  testWidgets('flexible plans list payments by date with a running total', (tester) async {
    await pumpView(tester, SchemeDetailsView(scheme: makeScheme(schemeType: 'SILVER_SMART'), flexible: true));

    expect(find.textContaining('months paid'), findsNothing);
    expect(find.text('Due'), findsNothing);
    expect(tester.getTopLeft(find.text('05 Mar 2026')).dy, lessThan(tester.getTopLeft(find.text('05 Jan 2026').last).dy));
    expect(find.text('total 12.013 g'), findsOneWidget); // newest row carries the cumulative weight
    expect(find.text('total 4.000 g'), findsOneWidget);
  });

  testWidgets('pay bar names the month being paid and calls back', (tester) async {
    var paid = 0;
    await pumpView(
        tester, PassbookPayBar(scheme: makeScheme(), flexible: false, paying: false, onPay: () => paid++));

    expect(find.text('Month 4 of 11 due'), findsOneWidget);
    expect(find.text('₹1,000'), findsOneWidget);
    await tester.tap(find.text('Pay now'));
    expect(paid, 1);
  });

  testWidgets('pay bar shows a spinner instead of the label while paying', (tester) async {
    await pumpView(tester, PassbookPayBar(scheme: makeScheme(), flexible: false, paying: true, onPay: () {}));

    expect(find.text('Pay now'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('no due month and no grams for a completed metal-less (Diwali) scheme', (tester) async {
    await pumpView(
      tester,
      SchemeDetailsView(scheme: makeScheme(schemeType: 'DIWALI', metal: null, status: 'Completed')),
    );

    expect(find.text('Due'), findsNothing);
    expect(find.textContaining(RegExp(r' g( |$)')), findsNothing);
    expect(find.textContaining('/g'), findsNothing);
  });
}
