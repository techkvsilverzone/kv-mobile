import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/catalog/data/catalog_repository.dart';

void main() {
  group('ProductFilters.toQuery', () {
    test('sends pagination and the default sort even when empty', () {
      final q = const ProductFilters().toQuery(page: 1, limit: 12);
      expect(q['page'], 1);
      expect(q['limit'], 12);
      // The param is `sortBy`, not `sort`.
      expect(q['sortBy'], 'newest');
      expect(q.containsKey('category'), isFalse);
      expect(q.containsKey('search'), isFalse);
    });

    test('comma-joins multi-select values into a single param', () {
      final q = const ProductFilters(
        categories: ['Silver', 'Gold'],
        metals: ['925', '999'],
      ).toQuery(page: 1, limit: 12);

      expect(q['category'], 'Silver,Gold');
      expect(q['metal'], '925,999');
    });

    test('omits an empty search rather than sending a blank param', () {
      final q = const ProductFilters(search: '').toQuery(page: 1, limit: 12);
      expect(q.containsKey('search'), isFalse);
    });

    test('maps sort options to the wire values the server accepts', () {
      expect(ProductSort.newest.wireValue, 'newest');
      expect(ProductSort.priceAsc.wireValue, 'price_asc');
      expect(ProductSort.priceDesc.wireValue, 'price_desc');
    });

    test('includes a price range when set', () {
      final q = const ProductFilters(minPrice: 500, maxPrice: 5000)
          .toQuery(page: 2, limit: 12);
      expect(q['minPrice'], 500);
      expect(q['maxPrice'], 5000);
      expect(q['page'], 2);
    });
  });

  group('copyWith', () {
    test('clearSearch removes the term instead of ignoring the null', () {
      const filters = ProductFilters(search: 'anklet');
      expect(filters.copyWith(clearSearch: true).search, isNull);
      // A plain null must not clear it — that is what the flag is for.
      expect(filters.copyWith().search, 'anklet');
    });

    test('clearPrice drops both bounds', () {
      const filters = ProductFilters(minPrice: 100, maxPrice: 900);
      final cleared = filters.copyWith(clearPrice: true);
      expect(cleared.minPrice, isNull);
      expect(cleared.maxPrice, isNull);
    });

    test('isEmpty ignores the sort order', () {
      expect(const ProductFilters(sort: ProductSort.priceAsc).isEmpty, isTrue);
      expect(const ProductFilters(categories: ['Silver']).isEmpty, isFalse);
    });
  });

  group('web Shop parity', () {
    test('sends subcategory and tags comma-joined', () {
      final q = const ProductFilters(subcategories: ['Rings', 'Anklets'], tags: ['new'])
          .toQuery(page: 1, limit: 12);
      expect(q['subcategory'], 'Rings,Anklets');
      expect(q['tags'], 'new');
    });

    test('"Featured" sorts as newest on the wire, as the web does', () {
      expect(ProductSort.featured.wireValue, 'newest');
      expect(ProductSort.featured.label, 'Featured');
    });

    test('category tree parses objects and tolerates bare strings', () {
      final node = CategoryNode.fromJson({'name': 'Jewellery', 'subcategories': ['Rings']});
      expect(node.name, 'Jewellery');
      expect(node.subcategories, ['Rings']);
      expect(CategoryNode.fromJson('Coins').name, 'Coins');
    });
  });
}
