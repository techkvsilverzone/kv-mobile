// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

/// A port of the web's design tokens (kv-ui/src/index.css `:root` and `.dark`)
/// rather than a seed-derived Material scheme, so the app shows the same colours.
///
/// The web's runtime theming (kv-ui/src/App.tsx `applyTheme`) overrides only
/// `--primary` and `--ring`, and sets them as inline styles, so the same
/// override applies in light and dark. An unknown or missing theme key leaves the
/// base graphite primary, exactly as on the web.
class AppTheme {
  const AppTheme._();

  /// `colorThemeCssVars` in kv-ui/src/App.tsx, as HSL triples.
  static const themePrimaries = <String, List<double>>{
    'ocean-teal': [195, 50, 45],
    'rose-gold': [350, 40, 50],
    'icy-silver': [210, 25, 45],
    'deep-amethyst': [270, 40, 45],
  };

  static Color hsl(double h, double s, double l) =>
      HSLColor.fromAHSL(1, h, s / 100, l / 100).toColor();

  /// Theme-independent metallic silver accents (`--silver*`).
  static Color silver(Brightness b) =>
      b == Brightness.light ? hsl(215, 12, 70) : hsl(214, 12, 62);

  static ThemeData build({String? themeKey, required Brightness brightness}) {
    final light = brightness == Brightness.light;
    final override = themePrimaries[themeKey];
    final primary = override != null
        ? hsl(override[0], override[1], override[2])
        : (light ? hsl(215, 18, 27) : hsl(210, 22, 74));

    final background = light ? hsl(220, 16, 97) : hsl(222, 20, 9);
    final foreground = light ? hsl(222, 18, 11) : hsl(213, 24, 94);
    final card = light ? hsl(0, 0, 100) : hsl(222, 18, 13);
    final cardForeground = light ? hsl(222, 16, 16) : hsl(213, 24, 94);
    final secondary = light ? hsl(214, 22, 95) : hsl(220, 16, 18);
    final secondaryForeground = light ? hsl(222, 16, 20) : hsl(213, 24, 94);
    final muted = light ? hsl(214, 20, 94) : hsl(220, 16, 18);
    final mutedForeground = light ? hsl(218, 10, 40) : hsl(215, 14, 66);
    final accent = light ? hsl(213, 24, 92) : hsl(216, 18, 24);
    final accentForeground = light ? hsl(216, 22, 26) : hsl(210, 22, 84);
    final destructive = light ? hsl(0, 70, 55) : hsl(0, 62, 45);
    final border = light ? hsl(216, 18, 89) : hsl(220, 14, 22);
    // `--primary-foreground`. With a themed (mid-lightness) primary the web still
    // uses the base value: white in light mode, near-black in dark mode.
    final onPrimary = light ? hsl(0, 0, 100) : hsl(222, 20, 10);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: accent,
      onPrimaryContainer: accentForeground,
      secondary: secondary,
      onSecondary: secondaryForeground,
      secondaryContainer: secondary,
      onSecondaryContainer: secondaryForeground,
      tertiary: accent,
      onTertiary: accentForeground,
      error: destructive,
      onError: hsl(0, 0, 98),
      surface: background,
      onSurface: foreground,
      onSurfaceVariant: mutedForeground,
      surfaceContainerLowest: card,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: muted,
      surfaceContainerHighest: muted,
      outline: border,
      outlineVariant: border,
      inversePrimary: primary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
    );

    // h1–h6 on the web: Playfair Display, tracking-tight, in the primary colour.
    TextStyle? heading(TextStyle? s) =>
        s?.copyWith(fontFamily: 'PlayfairDisplay', color: primary, letterSpacing: -0.4);
    final text = base.textTheme;

    final radius = BorderRadius.circular(8); // --radius: 0.5rem
    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: heading(text.displayLarge),
        displayMedium: heading(text.displayMedium),
        displaySmall: heading(text.displaySmall),
        headlineLarge: heading(text.headlineLarge),
        headlineMedium: heading(text.headlineMedium),
        headlineSmall: heading(text.headlineSmall),
        titleLarge: heading(text.titleLarge),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: border)),
        titleTextStyle: heading(text.titleLarge)?.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: border)),
      ),
      dividerTheme: DividerThemeData(color: border),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border)),
        enabledBorder:
            OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide(color: primary, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: radius),
            textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: radius),
            side: BorderSide(color: border),
            foregroundColor: foreground),
      ),
      chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: radius), side: BorderSide(color: border)),
      extensions: [KvColors(cardForeground: cardForeground, silver: silver(brightness))],
    );
  }
}

/// Web tokens with no Material slot.
class KvColors extends ThemeExtension<KvColors> {
  const KvColors({required this.cardForeground, required this.silver});

  final Color cardForeground;
  final Color silver;

  @override
  KvColors copyWith({Color? cardForeground, Color? silver}) => KvColors(
      cardForeground: cardForeground ?? this.cardForeground, silver: silver ?? this.silver);

  @override
  KvColors lerp(KvColors? other, double t) => other == null
      ? this
      : KvColors(
          cardForeground: Color.lerp(cardForeground, other.cardForeground, t)!,
          silver: Color.lerp(silver, other.silver, t)!);
}
