import 'package:flutter/material.dart';

/// Dark theme colors for the app.
///
/// Notes:
/// - Not a naive inversion of light colors.
/// - Keeps STP brand hue while tuning luminance for dark surfaces.
/// - Uses modern dark UI surfaces (deep background + slightly lighter elevated surfaces).
class AppDarkColors {
  AppDarkColors._();

  // Base surfaces
  static const Color background = Color(0xFF0B1418); // deep teal-tinted black
  static const Color surface = Color(0xFF101E24); // cards / sheets
  static const Color surfaceHigh =
      Color(0xFF15272F); // elevated / focused surface

  // Text / foreground
  static const Color foreground = Color(0xFFEAF2F5);
  static const Color mutedForeground = Color(0xFFB7C6CD);

  // Brand (keep hue of light primary 0xFF0078A5)
  static const Color primary =
      Color(0xFF4CA9C8); // brighter for dark backgrounds
  static const Color primaryForeground = Color(0xFF061014);
  static const Color primaryDark = Color(0xFF0078A5);
  static const Color primaryLight = Color(0xFF7BC3DB);

  // Secondary (cool, subtle)
  static const Color secondary = Color(0xFF182A33);
  static const Color secondaryForeground = foreground;
  static const Color secondaryLight = Color(0xFF1F3641);

  // Accent (deep neutral)
  static const Color accent = Color(0xFF223842);
  static const Color accentForeground = foreground;

  // Border / outlines
  static const Color border = Color(0xFF2B424C);
  static const Color ring = primary;

  // Inputs
  static const Color input = surfaceHigh;

  // Semantic
  static const Color destructive = Color(0xFFFF6B6B);
  static const Color destructiveForeground = Color(0xFF210606);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF60A5FA);

  // Legacy compatibility aliases (for older screens still using these names)
  static const Color card = surface;
  static const Color cardForeground = foreground;
  static const Color muted = Color(0xFF1D2D34);
  static const Color beige = background;
  static const Color beigeDark = Color(0xFF14232A);
  static const Color orange = Color(0xFFFFB36B);
  static const Color orangeLight = Color(0xFFFFD3A5);
  static const Color dark = background;
  static const Color darkCard = surface;
  static const Color lavender = Color(0xFFC4B5FD);
  static const Color lavenderLight = Color(0xFF2A2236);

  // Bottom navigation
  static const Color bottomNavBackground = Color(0xFF081014);
  static const Color bottomNavActive = foreground;
  static const Color bottomNavInactive = mutedForeground;

  // Overlays
  static const Color whiteOverlay20 = Color(0x33FFFFFF);
  static const Color whiteOverlay40 = Color(0x66FFFFFF);
  static const Color whiteOverlay10 = Color(0x1AFFFFFF);
  static const Color blackOverlay20 = Color(0x33000000);
}
