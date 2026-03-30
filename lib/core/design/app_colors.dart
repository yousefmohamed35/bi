import 'package:flutter/material.dart';

/// App Colors - Exact match to React CSS variables
/// Source: app/globals.css
class AppColors {
  AppColors._();

  // Base colors
  // App-wide background (matches brand secondary)
  static const Color background = Color(0xFFE5F3F6); // secondary
  static const Color foreground = Color(0xFF1A1A2E); // --foreground
  static const Color card = Color(0xFFFFFFFF); // --card
  static const Color cardForeground = Color(0xFF1A1A2E); // --card-foreground

  // Primary colors (STP brand)
  static const Color primary = Color(0xFF0078A5); // primary
  static const Color primaryForeground =
      Color(0xFFFFFFFF); // --primary-foreground
  static const Color primaryDark = Color(0xFF005777); // primary dark
  static const Color primaryLight = Color(0xFF4CA9C8); // primary light

  // Secondary colors
  static const Color secondary = Color(0xFFE5F3F6); // secondary
  static const Color secondaryForeground =
      Color(0xFF1A1A2E); // --secondary-foreground
  static const Color secondaryLight = Color(0xFFF4FBFC); // secondary light

  // Muted colors
  static const Color muted = Color(0xFFE8DDD4); // --beige-dark / --muted
  static const Color mutedForeground = Color(0xFF6B6B7B); // --muted-foreground

  // Accent colors
  static const Color accent = Color(0xFF2D2D3A); // --dark / --accent
  static const Color accentForeground =
      Color(0xFFFFFFFF); // --accent-foreground
  static const Color darkCard = Color(0xFF1E1E2D); // --dark-card

  // Border & Input
  static const Color border = Color(0xFFE8DDD4); // --border
  static const Color input = Color(0xFFFFFFFF); // --input
  static const Color ring = Color(0xFF0078A5); // --ring

  // Custom app colors
  // Keep legacy "beige" name but map to the app background
  static const Color beige = background;
  static const Color beigeDark = Color(0xFFE8DDD4); // --beige-dark
  static const Color orange = Color(0xFFF8A65D); // --orange
  static const Color orangeLight = Color(0xFFFEC89A); // --orange-light
  // Map legacy "purple" usages onto the new primary palette
  static const Color primaryMap = primary; // alias to primary
  static const Color primaryLightMap = primaryLight; // alias to primary light
  static const Color primaryDarkMap = primaryDark; // alias to primary dark
  static const Color dark = Color(0xFF2D2D3A); // --dark
  static const Color lavender = Color(0xFFC4B5FD); // --lavender
  static const Color lavenderLight = Color(0xFFE9E3FF); // --lavender-light

  // Semantic colors
  static const Color destructive = Color(0xFFDC2626);
  static const Color destructiveForeground = Color(0xFFDC2626);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Bottom navigation
  static const Color bottomNavBackground = Color(0xFF1A1A1A);
  static const Color bottomNavActive = Color(0xFFFFFFFF);
  static const Color bottomNavInactive = Color(0xFF9CA3AF);

  // Overlay colors
  static const Color whiteOverlay20 = Color(0x33FFFFFF);
  static const Color whiteOverlay40 = Color(0x66FFFFFF);
  static const Color whiteOverlay10 = Color(0x1AFFFFFF);
  static const Color blackOverlay20 = Color(0x33000000);
}
