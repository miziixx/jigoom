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

    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final tertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    final base = ThemeData(brightness: b, useMaterial3: true);
    final scheme = base.colorScheme.copyWith(
      brightness: b,
      // primary 를 텍스트색으로: 버튼/커서/포커스가 초록으로 새지 않게.
      // 초록(#34C77B)은 완료 체크 전용 — 위젯 코드에서만 명시적으로 사용.
      primary: primary,
      onPrimary: bg,
      secondary: secondary,
      surface: bg,
      surfaceTint: Colors.transparent, // M3 보라끼 틴트 제거
      outline: tertiary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      colorScheme: scheme,
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
        color: hairline,
      ),

      // 다이얼로그: 틴트 없는 플랫 카드 + 헤어라인.
      dialogTheme: DialogThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: hairline, width: 0.5),
        ),
        titleTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: primary),
        contentTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 15,
            color: primary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // 버튼: 채움=텍스트색(잉크), 텍스트버튼=회색. 초록 금지.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: bg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondary,
          textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 14),
        ),
      ),

      // 칩(필터): 얇은 헤어라인, 선택 시 잉크 반전. 체크 아이콘 없음.
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: bg,
        selectedColor: primary.withValues(alpha: 0.09),
        surfaceTintColor: Colors.transparent,
        showCheckmark: false,
        side: BorderSide(color: hairline, width: 0.5),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 13,
            color: primary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // 입력: 초록 대신 잉크색 커서/포커스 밑줄.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.15),
        selectionHandleColor: primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
            fontFamily: 'Pretendard', fontSize: 15, color: tertiary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: hairline, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1),
        ),
      ),

      // 하단 탭: 틴트 없는 심플 인디케이터.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: primary.withValues(alpha: 0.08),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: primary)),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 12,
            color: secondary)),
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
