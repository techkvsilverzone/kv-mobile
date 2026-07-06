import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/config/env.dart';

void main() {
  test('apiBaseUrl defaults to a valid, non-empty http(s) URL', () {
    expect(Env.apiBaseUrl, isNotEmpty);
    final uri = Uri.tryParse(Env.apiBaseUrl);
    expect(uri, isNotNull);
    expect(uri!.scheme, anyOf('http', 'https'));
  });
}
