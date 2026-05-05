import 'package:flutter/material.dart';

/// Brand & semantic color tokens for DocShelf.
///
/// Reference these constants everywhere — never hardcode a hex literal in
/// widgets. Changing a token here updates the whole app.
class AppColors {
  AppColors._();

  // ─── Brand ──────────────────────────────────────────────────────────
  /// Indigo — trust, security, document-vault feel. The primary brand color.
  static const Color primary = Color(0xFF3D5AFE);

  /// Deeper indigo — gradients, hover/pressed states on primary surfaces.
  static const Color primaryDark = Color(0xFF2D3FB8);

  /// Amber — warmth, "your stuff", CTAs and accents.
  static const Color accent = Color(0xFFFFB300);

  /// Deeper amber — pressed/hover for accent elements.
  static const Color accentDark = Color(0xFFFF8F00);

  // ─── Neutrals (light mode) ──────────────────────────────────────────
  /// Almost-black with a blue tint — body text in light mode.
  static const Color dark = Color(0xFF1A1F36);

  /// Secondary text & inactive icons.
  static const Color gray = Color(0xFF5C6678);

  /// Page background in light mode (very subtle blue).
  static const Color light = Color(0xFFF5F7FB);

  static const Color white = Color(0xFFFFFFFF);

  /// Card/surface in light mode.
  static const Color surface = Color(0xFFFFFFFF);

  // ─── Neutrals (dark mode) ───────────────────────────────────────────
  /// Card/surface in dark mode.
  static const Color surfaceDark = Color(0xFF1F2440);

  /// Page background in dark mode.
  static const Color bgDark = Color(0xFF12152A);

  // ─── Semantic ───────────────────────────────────────────────────────
  /// Green — "expires in 30+ days", "saved successfully".
  static const Color success = Color(0xFF2E7D32);

  /// Amber-yellow — "expires in 7 days", warnings.
  static const Color warning = Color(0xFFF9A825);

  /// Red — "expired", destructive actions.
  static const Color danger = Color(0xFFD32F2F);

  // ─── Utility helpers ────────────────────────────────────────────────
  // ─── Note backgrounds (sticky-note tints) ───────────────────────────
  /// Index 0 = default scaffold surface (no tint).
  /// 1..7 = soft tinted backgrounds. Designed to look correct in both
  /// light and dark mode — the editor mixes them at low alpha over the
  /// theme's surface color so they stay legible.
  static const List<Color> noteBgLight = [
    Color(0x00000000),  // 0 default — no tint
    Color(0xFFFFF9C4),  // yellow
    Color(0xFFDCEDC8),  // mint
    Color(0xFFB3E5FC),  // sky
    Color(0xFFFFCDD2),  // blush
    Color(0xFFE1BEE7),  // lavender
    Color(0xFFFFE0B2),  // peach
    Color(0xFFD7CCC8),  // taupe
  ];

  /// Same palette in muted dark-mode form (overlay opacity).
  static const List<Color> noteBgDark = [
    Color(0x00000000),
    Color(0x33FFEB3B),  // yellow @ 20%
    Color(0x338BC34A),  // mint
    Color(0x3303A9F4),  // sky
    Color(0x33EF5350),  // blush
    Color(0x33AB47BC),  // lavender
    Color(0x33FF9800),  // peach
    Color(0x338D6E63),  // taupe
  ];

  /// Standard indigo gradient used on hero banners and the splash screen.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  /// Amber gradient for accent CTAs.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDark],
  );
}
