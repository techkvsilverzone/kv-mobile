import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/cart/application/cart_controller.dart';
import 'package:kv_silver_mobile/features/cart/data/cart_repository.dart';
import 'package:kv_silver_mobile/features/catalog/data/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

Product _product({String id = 'p1', int stock = 10}) => Product.fromJson({
      '_id': id,
      'name': 'Silver Anklet',
      'weight': 20,
      'price': 2000,
      'listedPrice': 2000,
      'isFixedPrice': true,
      'inStock': stock > 0,
      'stockAvailable': stock,
      'variants': [
        {'label': 'S', 'weight': '20 g'},
        {'label': 'L', 'weight': '30 g'},
      ],
    });

class FakeCartRepository implements CartRepository {
  final List<({String productId, int quantity})> puts = [];
  final List<String> removes = [];
  bool shouldThrow = false;

  @override
  Future<void> putItem({required String productId, required int quantity}) async {
    if (shouldThrow) throw Exception('offline');
    puts.add((productId: productId, quantity: quantity));
  }

  @override
  Future<void> removeItem(String productId) async {
    if (shouldThrow) throw Exception('offline');
    removes.add(productId);
  }

  @override
  Future<List<({String productId, int quantity})>> fetchItems() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCartRepository repo;
  late CartController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = FakeCartRepository();
    controller = CartController(repo);
    await controller.load();
  });

  test('adds a line', () {
    controller.add(_product(), unitPrice: 2000);
    expect(controller.state.length, 1);
    expect(controller.state.single.quantity, 1);
    expect(controller.state.single.unitPrice, 2000);
  });

  test('adding the same variant twice merges into one line', () {
    final p = _product();
    controller.add(p, unitPrice: 2000, variant: p.variants.first);
    controller.add(p, unitPrice: 2000, variant: p.variants.first);

    expect(controller.state.length, 1);
    expect(controller.state.single.quantity, 2);
  });

  test('two variants of one product are two separate lines', () {
    // The server cart cannot express this — it keys on product alone — which is
    // exactly why the client holds the authoritative cart.
    final p = _product();
    controller.add(p, unitPrice: 2000, variant: p.variants[0]);
    controller.add(p, unitPrice: 3000, variant: p.variants[1]);

    expect(controller.state.length, 2);
    expect(controller.state.map((e) => e.variantWeight), ['20 g', '30 g']);
  });

  test('re-adding refreshes the price so a stale line reflects today rate', () {
    final p = _product();
    controller.add(p, unitPrice: 2000, variant: p.variants.first);
    controller.add(p, unitPrice: 2500, variant: p.variants.first);

    expect(controller.state.single.unitPrice, 2500);
  });

  test('setQuantity to zero removes the line', () {
    controller.add(_product(), unitPrice: 2000);
    controller.setQuantity(controller.state.single.lineKey, 0);
    expect(controller.state, isEmpty);
  });

  test('server sync sums quantities across variants of one product', () async {
    final p = _product();
    controller.add(p, unitPrice: 2000, variant: p.variants[0]);
    controller.add(p, unitPrice: 3000, variant: p.variants[1]);
    await Future<void>.delayed(Duration.zero);

    // Server gets one line for the product, quantity 2.
    expect(repo.puts.last.productId, 'p1');
    expect(repo.puts.last.quantity, 2);
  });

  test('a failed server sync never loses the local line', () async {
    repo.shouldThrow = true;
    controller.add(_product(), unitPrice: 2000);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.length, 1);
  });

  test('cart survives a restart via local storage', () async {
    final p = _product();
    controller.add(p, unitPrice: 2500, variant: p.variants[1]);
    await Future<void>.delayed(Duration.zero);

    final restored = CartController(repo);
    await restored.load();

    expect(restored.state.length, 1);
    // The variant weight survives — it would be lost if we rehydrated from the
    // server cart instead.
    expect(restored.state.single.variantWeight, '30 g');
    expect(restored.state.single.unitPrice, 2500);
  });

  test('refreshAvailability updates stock flags from the catalogue', () {
    controller.add(_product(stock: 5), unitPrice: 2000);
    controller.refreshAvailability({'p1': _product(stock: 0)});

    expect(controller.state.single.inStock, isFalse);
    expect(controller.state.single.stockAvailable, 0);
  });

  test('clear empties the cart and tells the server', () async {
    controller.add(_product(), unitPrice: 2000);
    await controller.clear();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, isEmpty);
    expect(repo.removes, contains('p1'));
  });

  test('order lines use `product` as the id key and carry the variant weight', () {
    final p = _product();
    controller.add(p, unitPrice: 2000, variant: p.variants[1], quantity: 3);

    final line = controller.state.single.toOrderLine();
    expect(line['product'], 'p1');
    expect(line['quantity'], 3);
    // variantWeight is the only channel a variant has to the server's pricing.
    expect(line['variantWeight'], '30 g');
    expect(line.containsKey('productId'), isFalse);
  });
}
