import 'package:flutter/material.dart';

/// 클린 아웃라이너 테마.
/// 포인트 색(#34C77B)은 완료 체크 전용. 다른 곳에 쓰지 말 것.
class AppColors {
  // 배경
  static const bgLight = Color(0xFFFFFFFF);
  static const bgDark = Color(0xFF111417);

  // 텍스트 (light)
  static const textPrimaryLight = Color(0xFF1A1A1A);
  static const textSecondaryLight = Color(0xFF6B6B6B);
  static const textTertiaryLight = Color(0xFFA0A0A0);

  // 텍스트 (dark, 반전)
  static const textPrimaryDark = Color(0xFFF2F2F2);
  static const textSecondaryDark = Color(0xFFB0B0B0);
  static const textTertiaryDark = Color(0xFF6B6B6B);

  /// 완료 체크 전용 포인트 색.
  static const done = Color(0xFF34C77B);

  static const hairlineLight = Color(0x14000000); // 0.5px 헤어라인
  static const hairlineDark = Color(0x1FFFFFFF);
}

const kAnimDuration = Duration(milliseconds: 200);
const kAnimCurve = Curves.easeOut;

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final primary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final base = ThemeData(brightness: b, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      colorScheme: base.colorScheme.copyWith(
        brightness: b,
        primary: AppColors.done,
        surface: bg,
      ),
      textTheme: _textTheme(primary, secondary),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: primary,
      ),
      cardTheme: const CardThemeData(elevation: 0),
      dividerTheme: DividerThemeData(
        thickness: 0.5,
        space: 0.5,
        color: isDark ? AppColors.hairlineDark : AppColors.hairlineLight,
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    const family = 'Pretendard';
    return TextTheme(
      titleLarge: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w600,
          fontSize: 22,
          color: primary),
      titleMedium: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w600,
          fontSize: 17,
          color: primary),
      bodyLarge: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: primary),
      bodyMedium: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w400,
          fontSize: 15,
          color: primary),
      bodySmall: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w400,
          fontSize: 13,
          color: secondary),
    );
  }
}
