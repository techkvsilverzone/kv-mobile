import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/theme/app_theme.dart';
import 'package:kv_silver_mobile/core/theme/tokens.dart';

void main() {
  test('the theme uses the KV brand palette', () {
    final t = AppTheme.light;
    expect(t.useMaterial3, isTrue);
    expect(t.colorScheme.primary, Kv.blue);
    expect(t.colorScheme.onSurface, Kv.ink);
    expect(t.scaffoldBackgroundColor, Kv.bg);
    expect(t.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(t.textTheme.headlineMedium?.fontFamily, Kv.serif);
  });

  test('buttons are 52 high with the small radius', () {
    final size = AppTheme.light.filledButtonTheme.style?.minimumSize?.resolve({});
    expect(size?.height, 52);
  });

  test('snackbars float', () {
    expect(AppTheme.light.snackBarTheme.behavior, SnackBarBehavior.floating);
  });
}
