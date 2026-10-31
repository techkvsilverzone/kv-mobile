import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/theme/app_theme.dart';

void main() {
  test('unthemed light uses the web base graphite primary and background', () {
    final t = AppTheme.build(brightness: Brightness.light);
    expect(t.colorScheme.primary, AppTheme.hsl(215, 18, 27));
    expect(t.scaffoldBackgroundColor, AppTheme.hsl(220, 16, 97));
  });

  test('a store theme overrides primary in both light and dark, like the web', () {
    final light = AppTheme.build(themeKey: 'deep-amethyst', brightness: Brightness.light);
    final dark = AppTheme.build(themeKey: 'deep-amethyst', brightness: Brightness.dark);
    expect(light.colorScheme.primary, AppTheme.hsl(270, 40, 45));
    expect(dark.colorScheme.primary, AppTheme.hsl(270, 40, 45));
    expect(dark.scaffoldBackgroundColor, AppTheme.hsl(222, 20, 9));
  });

  test('an unknown theme key keeps the base primary', () {
    final t = AppTheme.build(themeKey: 'nope', brightness: Brightness.dark);
    expect(t.colorScheme.primary, AppTheme.hsl(210, 22, 74));
  });
}
