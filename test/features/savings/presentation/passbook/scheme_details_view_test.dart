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
    expect(find.text('12.013 g'), findsOneWidget);
    expect(find.text('3 of 11'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.bySemanticsLabel('27% complete, 3 of 11 paid'), findsOneWidget);
  });

  testWidgets('lists month-wise history newest first with rate, amount, grams, mode and receipt number',
      (tester) async {
    await pumpView(tester, SchemeDetailsView(scheme: makeScheme()));

    final ys = [
      for (final m in ['Month 3', 'Month 2', 'Month 1']) tester.getTopLeft(find.text(m)).dy
    ];
    expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue);

    final month2 = find.byKey(const ValueKey('installment-102'));
    Finder inCard(Finder f) => find.descendant(of: month2, matching: f);
    expect(inCard(find.text('Month 2')), findsOneWidget);
    expect(inCard(find.text('₹240')), findsOneWidget);
    expect(inCard(find.text('4.167 g')), findsOneWidget);
    expect(inCard(find.text('Paid in store')), findsOneWidget);
    expect(inCard(find.text('Receipt No. 102')), findsOneWidget);
    expect(inCard(find.byTooltip('Download receipt for Month 2')), findsOneWidget);
  });

  testWidgets('labels the Pay button with the month being paid', (tester) async {
    var paid = 0;
    await pumpView(tester, SchemeDetailsView(scheme: makeScheme(), onPay: () => paid++));

    await tester.tap(find.text('Pay Month 4 of 11 (₹1,000)'));
    expect(paid, 1);
  });

  testWidgets('shows a spinner instead of the label while paying', (tester) async {
    await pumpView(tester, SchemeDetailsView(scheme: makeScheme(), onPay: () {}, paying: true));

    expect(find.textContaining('Pay Month'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('hides Pay when there is nothing due and grams for a metal-less (Diwali) scheme',
      (tester) async {
    await pumpView(
      tester,
      SchemeDetailsView(
          scheme: makeScheme(schemeType: 'DIWALI', metal: null, status: 'Completed'), onPay: () {}),
    );

    expect(find.textContaining(RegExp(r'^Pay Month')), findsNothing);
    expect(find.textContaining(RegExp(r' g$')), findsNothing);
    expect(find.text('Rate /g'), findsNothing);
  });
}
