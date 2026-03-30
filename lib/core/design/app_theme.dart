import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dark_colors.dart';
import 'app_text_styles.dart';
import 'app_radius.dart';
import '../../models/app_config.dart';

/// App Theme Configuration
class AppTheme {
  AppTheme._();

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required Color inputFillColor,
  }) {
    final textTheme = TextTheme(
      displayLarge: AppTextStyles.h1(),
      displayMedium: AppTextStyles.h2(),
      displaySmall: AppTextStyles.h3(),
      headlineMedium: AppTextStyles.h4(),
      bodyLarge: AppTextStyles.bodyLarge(),
      bodyMedium: AppTextStyles.bodyMedium(),
      bodySmall: AppTextStyles.bodySmall(),
      labelLarge: AppTextStyles.labelLarge(),
      labelMedium: AppTextStyles.labelMedium(),
      labelSmall: AppTextStyles.labelSmall(),
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      fontFamily: 'Cairo',
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorderRadius,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.4),
          disabledForegroundColor: colorScheme.onPrimary.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      // Align legacy paint targets & scaffold-adjacent surfaces with the same
      // background as [scaffoldBackgroundColor] for consistent dark/light UI.
      canvasColor: scaffoldBackgroundColor,
      splashColor: colorScheme.primary.withValues(alpha: 0.12),
      highlightColor: colorScheme.primary.withValues(alpha: 0.08),
      focusColor: colorScheme.primary.withValues(alpha: 0.14),
      hoverColor: colorScheme.primary.withValues(alpha: 0.06),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: colorScheme.onSurfaceVariant,
        modalBackgroundColor: colorScheme.surface,
        showDragHandle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
    );
  }

  static ThemeData lightTheme([ThemeConfig? themeConfig]) {
    // Use API config colors if provided, otherwise use default AppColors
    final primaryColor = AppColors.primary;
    final secondaryColor = AppColors.secondary;
    final cardColor = AppColors.card;
    final backgroundColor = AppColors.background;
    final errorColor = AppColors.destructive;
    final textColor = AppColors.foreground;

    final scheme = ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: cardColor,
      surfaceContainerHighest: AppColors.secondaryLight,
      background: backgroundColor,
      error: errorColor,
      onPrimary: AppColors.primaryForeground,
      onSecondary: AppColors.secondaryForeground,
      onSurface: textColor,
      onSurfaceVariant: AppColors.mutedForeground,
      onBackground: textColor,
      onError: AppColors.destructiveForeground,
      outline: AppColors.border,
      outlineVariant: AppColors.border.withValues(alpha: 0.6),
    );

    return _buildTheme(
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      inputFillColor: AppColors.input,
    );
  }

  static ThemeData darkTheme([ThemeConfig? themeConfig]) {
    // Use API config colors if provided, otherwise use dark palette defaults.
    //
    // Important: ThemeConfig coming from API is assumed to be "brand palette" not
    // a full dark-specific palette; we keep dark surfaces from AppDarkColors.
    final primaryColor = AppDarkColors.primary;
    final secondaryColor = AppDarkColors.secondary;
    final cardColor = AppDarkColors.surface;
    final backgroundColor = AppDarkColors.background;
    final errorColor = AppDarkColors.destructive;
    final textColor = AppDarkColors.foreground;

    final scheme = ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: cardColor,
      surfaceContainerHighest: AppDarkColors.surfaceHigh,
      background: backgroundColor,
      error: errorColor,
      onPrimary: AppDarkColors.primaryForeground,
      onSecondary: AppDarkColors.secondaryForeground,
      onSurface: textColor,
      onSurfaceVariant: AppDarkColors.mutedForeground,
      onBackground: textColor,
      onError: AppDarkColors.destructiveForeground,
      outline: AppDarkColors.border,
      outlineVariant: AppDarkColors.border.withValues(alpha: 0.7),
    );

    return _buildTheme(
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      inputFillColor: AppDarkColors.input,
    );
  }
}
