import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/widgets/links.dart';

void main() {
  test('hrefFor maps emails and phone numbers like the web hrefs', () {
    expect(hrefFor('kvszchennai@gmail.com'), 'mailto:kvszchennai@gmail.com');
    expect(hrefFor('(+91) 88256 49680'), 'tel:+918825649680');
    expect(hrefFor('https://wa.me/918825649680'), 'https://wa.me/918825649680');
  });
}
