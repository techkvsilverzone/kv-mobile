// test/core/theme/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/theme/app_theme.dart';

void main() {
  test('light theme uses Material 3 with light brightness', () {
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.light.colorScheme.primary, isNotNull);
  });

  test('dark theme uses Material 3 with dark brightness', () {
    expect(AppTheme.dark.useMaterial3, isTrue);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  test('brand primary color matches the website default (Ocean Teal)', () {
    expect(AppTheme.primary, const Color(0xFF398FAC));
  });
}
