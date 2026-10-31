import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/orders/data/models/order.dart';
import 'package:kv_silver_mobile/features/returns/request_return_dialog.dart';
import 'package:kv_silver_mobile/features/returns/returns.dart';

class _Returns implements ReturnsRepository {
  ({bool kvFault, String reason, List<ReturnItemInput> items})? sent;
  @override
  Future<List<ReturnRequest>> fetchMine() async => const [];
  @override
  Future<int?> fetchClaimWindowHours() async => 48;
  @override
  Future<VideoInstructions?> create(
      {required String orderId,
      required bool kvFault,
      required String reason,
      required String description,
      required List<ReturnItemInput> items}) async {
    sent = (kvFault: kvFault, reason: reason, items: items);
    return kvFault ? const VideoInstructions('+91 88256 49680', 'KV-7Q4M', 48) : null;
  }
}

final _order = Order.fromJson({
  '_id': 'o123456',
  'status': 'Delivered',
  'items': [
    {'productId': 'p1', 'productName': 'Anklet', 'quantity': 1, 'unitPrice': 1000, 'totalPrice': 1000},
    {'productId': 'p2', 'productName': 'Coin', 'quantity': 2, 'unitPrice': 500, 'totalPrice': 1000},
  ],
});

void main() {
  Future<_Returns> pump(WidgetTester tester) async {
    final repo = _Returns();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [returnsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: RequestReturnScreen(order: _order)),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('needs an item and a reason before submitting', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();
    expect(find.text('Select at least one item'), findsOneWidget);
    expect(find.text('Reason is required'), findsOneWidget);
    expect(repo.sent, isNull);
  });

  testWidgets('a KV-fault claim sends the picked items and shows the video code', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Coin'));
    await tester.enterText(find.widgetWithText(TextField, 'Short reason'), 'Dented');
    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();

    expect(repo.sent?.kvFault, isTrue);
    expect(repo.sent?.reason, 'Dented');
    expect(repo.sent?.items.single.toJson(), {'product': 'p2', 'name': 'Coin', 'quantity': 2, 'price': 500.0});
    expect(find.text('KV-7Q4M'), findsOneWidget);
    expect(find.text('+91 88256 49680'), findsOneWidget);
  });

  testWidgets('a change-of-mind return explains exchange or store credit', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Anklet'));
    await tester.tap(find.text('Changed my mind / other'));
    await tester.enterText(find.widgetWithText(TextField, 'Short reason'), 'Too small');
    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();

    expect(repo.sent?.kvFault, isFalse);
    expect(find.textContaining('exchange or store credit only'), findsOneWidget);
  });
}
