import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/catalog/data/models/product.dart';

void main() {
  test('server-relative image paths resolve against the API origin', () {
    expect(resolveApiOrigin('https://api.kvsilverzone.com/api/v1'), 'https://api.kvsilverzone.com');
    const rel = ProductImage(data: '/images/products/x/001.webp', sortOrder: 0);
    expect(rel.isRemote, isTrue);
    expect(rel.url, endsWith('/images/products/x/001.webp'));
    const abs = ProductImage(data: 'https://cdn.example.com/a.webp', sortOrder: 0);
    expect(abs.url, 'https://cdn.example.com/a.webp');
    const b64 = ProductImage(data: 'iVBORw0KGgo=', sortOrder: 0);
    expect(b64.isRemote, isFalse);
  });
}
