import 'package:flutter/material.dart';

/// Brand tokens (docs/design-system.md). Colours come from the KV logo.
abstract final class Kv {
  static const ink = Color(0xFF1F1B1C);
  static const blue = Color(0xFF2F6CB0);
  static const blueDark = Color(0xFF245891);
  static const blueSoft = Color(0xFFEAF1FA);
  static const bg = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE7E9EE);
  static const muted = Color(0xFF6B7280);
  static const subtle = Color(0xFF9AA1AC);
  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFE8F5EC);
  static const warning = Color(0xFFB45309);
  static const warningSoft = Color(0xFFFEF3E2);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFDECEC);
  static const gold = Color(0xFFB08A3E);
  static const goldSoft = Color(0xFFF7F0E1);

  static const pad = 16.0;
  static const gap = 24.0;
  static const radius = 16.0;
  static const radiusSm = 12.0;

  static final cardRadius = BorderRadius.circular(radius);
  static final smallRadius = BorderRadius.circular(radiusSm);

  /// Brand-moment serif (splash, greetings, auth titles only).
  static const serif = 'PlayfairDisplay';

  static const floatingShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, -4)),
  ];
}
