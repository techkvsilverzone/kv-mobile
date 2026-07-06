// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

/// Matches kv-silver-zone's default runtime theme ("Ocean Teal", HSL 195 50% 45%,
/// see kv-silver-zone/src/App.tsx's colorThemeCssVars). The web app lets admins
/// switch to other palettes at runtime (rose-gold, icy-silver, deep-amethyst);
/// this app ships with the default only for Phase 1.
class AppTheme {
  const AppTheme._();

  static const Color primary = Color(0xFF398FAC);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark),
      );
}
