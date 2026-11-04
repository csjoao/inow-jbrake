import 'package:flutter/material.dart';

/// Cores do app oficial: fundo cinza-claro, cartões brancos, amarelo INOW.
abstract final class AppColors {
  static const yellow = Color(0xFFF5D547);
  static const background = Color(0xFFF2F3F5);
  static const card = Colors.white;
  static const text = Color(0xFF111111);
  static const muted = Color(0xFF8E8E93);
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.yellow,
      primary: AppColors.yellow,
      onPrimary: AppColors.text,
      surface: AppColors.background,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.yellow
              : const Color(0xFFE5E5EA),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
