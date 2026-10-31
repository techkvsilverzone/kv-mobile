import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/auth/auth_session.dart';
import 'package:kv_silver_mobile/features/auth/application/address_controller.dart';
import 'package:kv_silver_mobile/features/catalog/application/catalog_providers.dart';
import 'package:kv_silver_mobile/features/catalog/data/catalog_repository.dart';
import 'package:kv_silver_mobile/features/dashboard/dashboard_screen.dart';
import 'package:kv_silver_mobile/features/orders/data/order_repository.dart';
import 'package:kv_silver_mobile/features/rates/presentation/rates_screen.dart';
import 'package:kv_silver_mobile/features/savings/data/savings_models.dart';
import 'package:kv_silver_mobile/features/savings/data/savings_repository.dart';
import 'package:kv_silver_mobile/features/savings/presentation/passbook/passbook_screen.dart';
import 'package:kv_silver_mobile/features/savings/presentation/plan_detail_screen.dart';
import 'package:kv_silver_mobile/features/savings/presentation/savings_info_screen.dart';
import 'package:kv_silver_mobile/features/savings/presentation/savings_scheme_screen.dart';
import 'package:kv_silver_mobile/features/savings/presentation/widgets/scheme_widgets.dart';
import 'fixtures.dart';
import 'savings_fixtures.dart';
import 'screenshot.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('razorpay_flutter'), (_) async => null);
  });

  final rates = [
    silverRatesProvider.overrideWith((ref) async => silverToday),
    goldRatesProvider.overrideWith((ref) async => goldToday),
    rateHistoryProvider.overrideWith((ref, key) async => key.$1 == Metal.silver ? silverHistory30 : goldHistory30),
  ];
  final plans = [...rates, schemePlansProvider.overrideWith((ref) async => [samplePlan(0), samplePlan(1), samplePlan(2)])];
  final guest = [...plans, currentUserProvider.overrideWithValue(null)];
  final member = [
    ...plans,
    currentUserProvider.overrideWithValue(sampleUser),
    mySchemesProvider.overrideWith((ref) async => [silverScheme(), goldScheme(), smartScheme()]),
    addressListProvider.overrideWith((ref) => AddressListController(NoAddressRepo())),
    myOrdersProvider.overrideWith((ref) async => [sampleOrder(4), sampleOrder(3, status: 'Pending'), sampleOrder(1, status: 'Delivered')]),
  ];
  List passbook(dynamic scheme) => [...member, passbookProvider.overrideWith((ref, n) async => scheme)];

  testWidgets('savings guest', (t) => screenshot(t, 'savings_guest', const SavingsSchemeScreen(), overrides: guest));
  testWidgets('savings guest scrolled', (t) => screenshot(t, 'savings_guest_scrolled', const SavingsSchemeScreen(), overrides: guest, scroll: 500));
  testWidgets('savings member', (t) => screenshot(t, 'savings_member', const SavingsSchemeScreen(), overrides: member));
  testWidgets('savings member scrolled', (t) => screenshot(t, 'savings_member_scrolled', const SavingsSchemeScreen(), overrides: member, scroll: 900));
  testWidgets('savings loading', (t) => screenshot(t, 'savings_loading', const SavingsSchemeScreen(), overrides: [
        ...rates,
        currentUserProvider.overrideWithValue(sampleUser),
        schemePlansProvider.overrideWith((ref) => Completer<List<SchemePlan>>().future),
        mySchemesProvider.overrideWith((ref) => Completer<List<SavingsEnrollment>>().future),
      ]));
  testWidgets('plan detail', (t) => screenshot(t, 'plan_detail', PlanDetailScreen(plan: samplePlan(0)), overrides: guest));
  testWidgets('plan detail scrolled', (t) => screenshot(t, 'plan_detail_scrolled', PlanDetailScreen(plan: samplePlan(1)), overrides: member, scroll: 500));
  testWidgets('plan detail flexible', (t) => screenshot(t, 'plan_detail_flexible', PlanDetailScreen(plan: samplePlan(2)), overrides: member));
  testWidgets('enrol otp sheet', (t) => screenshot(t, 'enrol_otp', Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) => showEnrollOtpSheet(context, channel: 'whatsapp'));
        return PlanDetailScreen(plan: samplePlan(0));
      }), overrides: member));
  testWidgets('savings info', (t) => screenshot(t, 'savings_info', const SavingsInfoScreen(), before: (t) async {
        await t.tap(find.text('What happens if I miss a payment?'));
        await t.pump(const Duration(milliseconds: 400));
      }));
  testWidgets('passbook fixed', (t) => screenshot(t, 'passbook_fixed', const PassbookScreen(passbookNumber: 'x'), overrides: passbook(silverScheme()).cast()));
  testWidgets('passbook fixed scrolled', (t) => screenshot(t, 'passbook_fixed_scrolled', const PassbookScreen(passbookNumber: 'x'), overrides: passbook(silverScheme()).cast(), scroll: 400));
  testWidgets('passbook flexible', (t) => screenshot(t, 'passbook_flexible', const PassbookScreen(passbookNumber: 'x'), overrides: passbook(smartScheme()).cast()));
  testWidgets('passbook missing', (t) => screenshot(t, 'passbook_missing', const PassbookScreen(passbookNumber: 'x'), overrides: [
        ...member,
        passbookProvider.overrideWith((ref, n) async => throw Exception('404')),
      ]));
  testWidgets('rates', (t) => screenshot(t, 'rates', const RatesScreen(), overrides: rates));
  testWidgets('rates scrolled', (t) => screenshot(t, 'rates_scrolled', const RatesScreen(), overrides: rates, scroll: 500));
  testWidgets('dashboard', (t) => screenshot(t, 'dashboard', const DashboardScreen(), overrides: member));
}
