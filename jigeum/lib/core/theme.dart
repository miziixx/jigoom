import 'package:flutter/material.dart';

/// 디자인 시스템 토큰 — DESIGN_SYSTEM.md 참조. 하드코딩 대신 항상 이 토큰 사용.
/// 미학: "따뜻한 종이 + 차분한 구조". 포인트는 accent(보라)·alert(주황) 둘뿐.
class AppColors {
  // 중립 — 따뜻한 회색(종이)
  static const bgLight = Color(0xFFFDFCFB); // bg
  static const bgSubtleLight = Color(0xFFF5F3F0); // bg-subtle
  static const borderLight = Color(0xFFE8E4DF); // border
  static const textPrimaryLight = Color(0xFF1C1B1A); // text
  static const textSecondaryLight = Color(0xFF8A8580); // text-muted
  static const textTertiaryLight = Color(0xFFC4BFB9); // disabled

  // 다크 (반전)
  static const bgDark = Color(0xFF15140F);
  static const bgSubtleDark = Color(0xFF1F1D18);
  static const borderDark = Color(0xFF34322C);
  static const textPrimaryDark = Color(0xFFF2F0EC);
  static const textSecondaryDark = Color(0xFF9A958E);
  static const textTertiaryDark = Color(0xFF57534D);

  // 포인트 — 딱 둘
  static const accent = Color(0xFF6B4EFF); // 보라: 액션·링크·활성 체크박스
  static const alert = Color(0xFFFF5B24); // 주황: 오늘 표시·마감 임박

  // 상태
  static const success = Color(0xFF2E9E5B);
  static const warning = Color(0xFFE0A400);
  static const error = Color(0xFFE5484D);
  static const disabled = Color(0xFFC4BFB9);

  /// 완료 체크는 accent(보라) — DESIGN_SYSTEM §5 체크박스.
  static const done = accent;

  // 하위호환 별칭 (기존 코드가 참조)
  static const hairlineLight = borderLight;
  static const hairlineDark = borderDark;
}

/// 간격 토큰 (4px 배수).
class AppSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s8 = 48.0;
}

class AppRadius {
  static const sm = 6.0;
  static const md = 10.0;
  static const full = 999.0;
}

/// 메타·숫자·시간·배지용 모노스페이스. (JetBrains Mono 미번들 → 안드로이드 generic)
const kMonoFamily = 'monospace';

const kAnimDuration = Duration(milliseconds: 200);
const kAnimCurve = Curves.easeOut;

/// 굵기 조절: FontWeight 을 delta 만큼 이동 (w400=index3 기준).
FontWeight shiftWeight(FontWeight base, int delta) {
  const order = [
    FontWeight.w100,
    FontWeight.w200,
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
    FontWeight.w900,
  ];
  final i = (order.indexOf(base) + delta).clamp(0, order.length - 1);
  return order[i];
}

class AppTheme {
  static ThemeData light({int weightDelta = 0}) =>
      _build(Brightness.light, weightDelta);
  static ThemeData dark({int weightDelta = 0}) =>
      _build(Brightness.dark, weightDelta);

  static ThemeData _build(Brightness b, [int weightDelta = 0]) {
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
      // primary = accent(보라): 버튼·링크·활성 체크박스·커서. (DESIGN_SYSTEM §1)
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: secondary,
      surface: bg,
      surfaceTint: Colors.transparent, // M3 자동 틴트 제거 (의도된 accent 만 사용)
      outline: tertiary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      colorScheme: scheme,
      textTheme: _textTheme(primary, secondary, weightDelta),
      // 드로어·팝업: M3 보라 틴트 제거, 흰 톤 + 헤어라인.
      drawerTheme: DrawerThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.horizontal(right: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: hairline, width: 0.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: secondary,
        textColor: primary,
      ),
      // 전역 밀도: 터치영역 부풀림 없이 컴팩트하게.
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(34, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: primary,
        toolbarHeight: 52,
        titleTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: primary),
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

      // 버튼: 채움=accent(보라), 텍스트버튼=회색. (DESIGN_SYSTEM §1 액션)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
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
        selectedColor: AppColors.accent.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        showCheckmark: false,
        side: BorderSide(color: hairline, width: 1),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 13,
            color: primary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // 입력: accent 커서/포커스.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accent.withValues(alpha: 0.18),
        selectionHandleColor: AppColors.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
            fontFamily: 'Pretendard', fontSize: 15, color: tertiary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),

      // 하단 탭: 틴트 없는 심플 인디케이터.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        // 선택 탭: accent 톤 인디케이터 + accent 아이콘.
        indicatorColor: AppColors.accent.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : secondary)),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: secondary)),
      ),
    );
  }

  static TextTheme _textTheme(
      Color primary, Color secondary, int weightDelta) {
    const family = 'Pretendard';
    final reg = shiftWeight(FontWeight.w400, weightDelta);
    final semi = shiftWeight(FontWeight.w600, weightDelta);
    return TextTheme(
      titleLarge: TextStyle(
          fontFamily: family, fontWeight: semi, fontSize: 22, color: primary),
      titleMedium: TextStyle(
          fontFamily: family, fontWeight: semi, fontSize: 17, color: primary),
      bodyLarge: TextStyle(
          fontFamily: family, fontWeight: reg, fontSize: 16, color: primary),
      bodyMedium: TextStyle(
          fontFamily: family, fontWeight: reg, fontSize: 15, color: primary),
      bodySmall: TextStyle(
          fontFamily: family, fontWeight: reg, fontSize: 13, color: secondary),
    );
  }
}
