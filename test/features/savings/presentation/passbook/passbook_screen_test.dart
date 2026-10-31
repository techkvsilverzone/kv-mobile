import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/api/api_exception.dart';
import 'package:kv_silver_mobile/core/auth/auth_session.dart';
import 'package:kv_silver_mobile/features/auth/application/address_controller.dart';
import 'package:kv_silver_mobile/features/auth/data/address_repository.dart';
import 'package:kv_silver_mobile/features/auth/data/models/address.dart';
import 'package:kv_silver_mobile/features/auth/data/models/user.dart';
import 'package:kv_silver_mobile/features/savings/data/savings_models.dart';
import 'package:kv_silver_mobile/features/savings/data/savings_repository.dart';
import 'package:kv_silver_mobile/features/savings/presentation/passbook/passbook_screen.dart';

Future<void> pumpWithError(WidgetTester tester, ApiException error) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(null),
      passbookProvider.overrideWith((ref, number) async => throw error),
    ],
    child: const MaterialApp(home: PassbookScreen(passbookNumber: 'SLV-0007')),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("tells the customer when the passbook isn't theirs (403)", (tester) async {
    await pumpWithError(tester, const ServerException(403, 'Forbidden'));

    expect(find.text('This passbook belongs to another customer.'), findsOneWidget);
    expect(find.text('Back to my schemes'), findsOneWidget);
    expect(find.byTooltip('Print passbook'), findsNothing);
  });

  testWidgets('any other failure reads as not found', (tester) async {
    await pumpWithError(tester, const ServerException(404, 'Not found'));

    expect(find.text('No savings plan found for this passbook number.'), findsOneWidget);
  });

  mainData();
}

SavingsEnrollment _scheme(String type) => SavingsEnrollment(
      id: 's1',
      owner: const SchemeOwner(id: 'u1', name: 'Vino', phone: '9876543210'),
      passbookNumber: 'SLV-0007',
      schemeType: type,
      metal: 'SILVER',
      monthlyAmount: 1000,
      duration: 11,
      startDate: '2026-01-05T00:00:00Z',
      status: 'Active',
      totalPaid: 2000,
      bonusAmount: 0,
      payments: const [
        SavingsPayment(
            id: '2',
            month: 0,
            amount: 1000,
            paidAt: '2026-02-05T12:00:00Z',
            materialRate: 240,
            materialWeight: 4.167,
            devidentAmount: 0,
            devidentMaterialRate: 0,
            devidentMaterialWeight: 0),
        SavingsPayment(
            id: '1',
            month: 0,
            amount: 1000,
            paidAt: '2026-01-05T12:00:00Z',
            materialRate: 250,
            materialWeight: 4,
            devidentAmount: 0,
            devidentMaterialRate: 0,
            devidentMaterialWeight: 0),
      ],
    );

Future<void> pumpScheme(WidgetTester tester, SavingsEnrollment scheme, {bool flexible = false, User? user}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(user),
      addressListProvider.overrideWith((ref) => AddressListController(_NoAddresses())),
      passbookProvider.overrideWith((ref, number) async => scheme),
      schemePlansProvider.overrideWith((ref) async => [
            SchemePlan(
                id: 'p',
                type: scheme.schemeType,
                name: 'Plan',
                durationMonths: 11,
                bonusMonths: 0,
                isFlexible: flexible,
                monthlyAmounts: const []),
          ]),
    ],
    child: const MaterialApp(home: PassbookScreen(passbookNumber: 'SLV-0007')),
  ));
  await tester.pumpAndSettle();
}

void mainData() {
  testWidgets('fixed plan: details view on screen, ledger only painted for print', (tester) async {
    await pumpScheme(tester, _scheme('SILVER_11_1'));

    expect(find.byTooltip('Print passbook'), findsOneWidget);
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.text('Pay now'), findsNothing); // only the owner may pay
    expect(find.text('Ledger Statement'), findsOneWidget); // the hidden print copy
  });

  testWidgets('the owner gets a Pay bar for the next month', (tester) async {
    await pumpScheme(tester, _scheme('SILVER_11_1'),
        user: const User(id: 'u1', name: 'Vino', email: 'v@x.in', role: 'customer'));

    expect(find.text('Pay now'), findsOneWidget);
    expect(find.text('Month 3 of 11 due'), findsOneWidget);
  });

  testWidgets('flexible plan: app list on screen, print ledger oldest first with a running total',
      (tester) async {
    await pumpScheme(tester, _scheme('SILVER_SMART'), flexible: true);

    expect(find.text('Payment history'), findsOneWidget);
    expect(find.textContaining('months paid'), findsNothing);
    // The printable ledger (painted beneath the page) keeps the shop's paper layout.
    expect(
        tester.getTopLeft(find.text('05 Jan 26')).dy, lessThan(tester.getTopLeft(find.text('05 Feb 26')).dy));
    // last row's cumulative + footer material weight, total and cumulative
    expect(find.text('8.167'), findsNWidgets(4));
    expect(find.text('₹2,000 · 8.167 g silver'), findsOneWidget);
    expect(find.text(': Vino'), findsOneWidget);
    expect(find.text(': 1,000'), findsOneWidget);
  });
}

class _NoAddresses implements AddressRepository {
  @override
  Future<List<Address>> list() async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
