import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';

/// The app's single light theme, built from [Kv] tokens.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Kv.blue,
      onPrimary: Colors.white,
      primaryContainer: Kv.blueSoft,
      onPrimaryContainer: Kv.blueDark,
      secondary: Kv.ink,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEDEEF1),
      onSecondaryContainer: Kv.ink,
      tertiary: Kv.gold,
      onTertiary: Colors.white,
      tertiaryContainer: Kv.goldSoft,
      onTertiaryContainer: Color(0xFF6B5221),
      error: Kv.danger,
      onError: Colors.white,
      errorContainer: Kv.dangerSoft,
      onErrorContainer: Color(0xFF8F1D1D),
      surface: Kv.surface,
      onSurface: Kv.ink,
      onSurfaceVariant: Kv.muted,
      surfaceContainerLowest: Kv.surface,
      surfaceContainerLow: Color(0xFFFAFAFB),
      surfaceContainer: Kv.bg,
      surfaceContainerHigh: Color(0xFFEFF1F4),
      surfaceContainerHighest: Color(0xFFE9ECF0),
      outline: Color(0xFFD5D9E0),
      outlineVariant: Kv.line,
      inverseSurface: Kv.ink,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFF9DBFE8),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Inter');
    final t = base.textTheme.apply(bodyColor: Kv.ink, displayColor: Kv.ink);
    final text = t.copyWith(
      displaySmall: t.displaySmall?.copyWith(fontFamily: Kv.serif, fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineMedium: t.headlineMedium?.copyWith(fontFamily: Kv.serif, fontWeight: FontWeight.w600, letterSpacing: -0.4),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3, fontSize: 22),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: -0.2),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: t.bodySmall?.copyWith(fontSize: 12.5, color: Kv.muted, height: 1.4),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
      labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w500, color: Kv.muted),
      labelSmall: t.labelSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2, color: Kv.muted),
    );

    const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Kv.radiusSm)));
    const buttonSize = Size(64, 52);
    final inputBorder = OutlineInputBorder(borderRadius: Kv.smallRadius, borderSide: const BorderSide(color: Kv.line));

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: Kv.bg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Kv.surface,
        foregroundColor: Kv.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black26,
        centerTitle: false,
        titleTextStyle: text.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: Kv.ink),
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Kv.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Kv.blueSoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? Kv.ink : Kv.muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? Kv.blue : Kv.muted)),
      ),
      cardTheme: CardThemeData(
        color: Kv.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Kv.cardRadius, side: const BorderSide(color: Kv.line)),
      ),
      dividerTheme: const DividerThemeData(color: Kv.line, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
          disabledBackgroundColor: const Color(0xFFDDE1E7),
          disabledForegroundColor: Kv.subtle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          foregroundColor: Kv.ink,
          side: const BorderSide(color: Color(0xFFD5D9E0)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Kv.blue,
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Kv.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: Kv.blue, width: 1.6)),
        errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: Kv.danger)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: Kv.danger, width: 1.6)),
        labelStyle: const TextStyle(color: Kv.muted),
        floatingLabelStyle: const TextStyle(color: Kv.blue, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Kv.subtle),
        prefixIconColor: Kv.muted,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Kv.surface,
        selectedColor: Kv.blueSoft,
        side: const BorderSide(color: Kv.line),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: Kv.ink),
        secondaryLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Kv.blueDark),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Kv.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: Color(0xFFD5D9E0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Kv.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: text.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Kv.ink,
        contentTextStyle: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 14),
        actionTextColor: const Color(0xFF9DBFE8),
        shape: RoundedRectangleBorder(borderRadius: Kv.smallRadius),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Kv.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
        titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w500, color: Kv.ink),
        subtitleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Kv.muted),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Kv.ink,
        unselectedLabelColor: Kv.muted,
        indicatorColor: Kv.blue,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Kv.line,
        labelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: Kv.blueSoft,
          selectedForegroundColor: Kv.blueDark,
          side: const BorderSide(color: Kv.line),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Kv.blue : null),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Kv.blue),
      badgeTheme: const BadgeThemeData(backgroundColor: Kv.danger, textColor: Colors.white),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
