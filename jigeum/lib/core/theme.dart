import 'package:flutter/material.dart';

import 'constants.dart';

/// 6토큰 잉크 시스템 (DESIGN_SYSTEM §1). 테마가 이 인스턴스를 통째로 교체한다.
/// 컴포넌트는 색을 하드코딩하지 않고 이 토큰만 참조한다 → 10종이 자동 대응.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.paper,
    required this.paper2,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.mark,
  });

  final Color paper; // 종이 — 기본 배경
  final Color paper2; // 종이(짙음) — 눌림·선택 배경
  final Color ink; // 잉크 — 본문·제목·활성·규칙선
  final Color inkSoft; // 흐린 잉크 — 메타·카운트·placeholder·비활성
  final Color line; // 규칙선 — 얇은 구분선·섹션 fill
  final Color mark; // 포인트 — 긴급(URGENT)·프롬프트 캐럿에만

  bool get isDark => paper.computeLuminance() < 0.5;

  @override
  AppTokens copyWith({
    Color? paper,
    Color? paper2,
    Color? ink,
    Color? inkSoft,
    Color? line,
    Color? mark,
  }) =>
      AppTokens(
        paper: paper ?? this.paper,
        paper2: paper2 ?? this.paper2,
        ink: ink ?? this.ink,
        inkSoft: inkSoft ?? this.inkSoft,
        line: line ?? this.line,
        mark: mark ?? this.mark,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      paper: Color.lerp(paper, other.paper, t)!,
      paper2: Color.lerp(paper2, other.paper2, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      line: Color.lerp(line, other.line, t)!,
      mark: Color.lerp(mark, other.mark, t)!,
    );
  }
}

/// 기능 상태색 (테마 무관 — DESIGN_SYSTEM §1 functional). 극소량.
class AppState {
  static const success = Color(0xFF4F7A4A);
  static const warning = Color(0xFFB08A2E);
  static const error = Color(0xFFB0392E);
}

/// 내장 테마 한 종의 정의(키 + 이름 + 6토큰).
class ThemeSpec {
  const ThemeSpec(this.key, this.name, this.tokens);
  final String key;
  final String name;
  final AppTokens tokens;
}

/// 내장 10종 — 9 라이트 + 1 다크(NOIR). 기본 MANILA. (DESIGN_SYSTEM §1-1)
const List<ThemeSpec> kThemes = [
  ThemeSpec(
      'manila',
      'MANILA',
      AppTokens(
          paper: Color(0xFFF4F1EA),
          paper2: Color(0xFFEFEBE2),
          ink: Color(0xFF26241F),
          inkSoft: Color(0xFF9A948A),
          line: Color(0xFFD8D2C6),
          mark: Color(0xFFB5443A))),
  ThemeSpec(
      'newsprint',
      'NEWSPRINT',
      AppTokens(
          paper: Color(0xFFEDEBE6),
          paper2: Color(0xFFE6E3DC),
          ink: Color(0xFF1C1C1A),
          inkSoft: Color(0xFF8C8A84),
          line: Color(0xFFD2CFC8),
          mark: Color(0xFFC4362B))),
  ThemeSpec(
      'sage',
      'SAGE',
      AppTokens(
          paper: Color(0xFFE9EAE0),
          paper2: Color(0xFFE1E3D6),
          ink: Color(0xFF2E362B),
          inkSoft: Color(0xFF949A88),
          line: Color(0xFFCFD3C3),
          mark: Color(0xFF5E7048))),
  ThemeSpec(
      'midnight',
      'MIDNIGHT',
      AppTokens(
          paper: Color(0xFFEFE9DD),
          paper2: Color(0xFFE8E1D2),
          ink: Color(0xFF1B2A3A),
          inkSoft: Color(0xFF8C93A0),
          line: Color(0xFFD5CFC0),
          mark: Color(0xFFB5443A))),
  ThemeSpec(
      'terracotta',
      'TERRACOTTA',
      AppTokens(
          paper: Color(0xFFF0E4D8),
          paper2: Color(0xFFE9DACB),
          ink: Color(0xFF3A2A20),
          inkSoft: Color(0xFFA8917E),
          line: Color(0xFFE0CCB8),
          mark: Color(0xFFC0603A))),
  ThemeSpec(
      'olive',
      'OLIVE',
      AppTokens(
          paper: Color(0xFFEAE7D6),
          paper2: Color(0xFFE2DEC9),
          ink: Color(0xFF33321F),
          inkSoft: Color(0xFF9A9678),
          line: Color(0xFFD3CFB6),
          mark: Color(0xFF7A6A2E))),
  ThemeSpec(
      'slate',
      'SLATE',
      AppTokens(
          paper: Color(0xFFE6E8EA),
          paper2: Color(0xFFDDE0E3),
          ink: Color(0xFF23292E),
          inkSoft: Color(0xFF8A9196),
          line: Color(0xFFCDD1D4),
          mark: Color(0xFF4A5A66))),
  ThemeSpec(
      'rose',
      'DUSTY ROSE',
      AppTokens(
          paper: Color(0xFFF0E7E4),
          paper2: Color(0xFFE9DBD7),
          ink: Color(0xFF322523),
          inkSoft: Color(0xFFA8908C),
          line: Color(0xFFDDCCC8),
          mark: Color(0xFFA64B54))),
  ThemeSpec(
      'plum',
      'PLUM',
      AppTokens(
          paper: Color(0xFFECE6EA),
          paper2: Color(0xFFE3DBE1),
          ink: Color(0xFF2C2330),
          inkSoft: Color(0xFF978C9C),
          line: Color(0xFFD6CCD6),
          mark: Color(0xFF7A4A6E))),
  ThemeSpec(
      'noir',
      'NOIR',
      AppTokens(
          paper: Color(0xFF201E1A),
          paper2: Color(0xFF2A2722),
          ink: Color(0xFFEDE7D9),
          inkSoft: Color(0xFF7A756B),
          line: Color(0xFF3A3630),
          mark: Color(0xFFD46A4A))),
];

const String kDefaultThemeKey = 'manila';

AppTokens tokensForKey(String key) {
  for (final t in kThemes) {
    if (t.key == key) return t.tokens;
  }
  return kThemes.first.tokens;
}

/// 현재 테마의 6토큰. 컴포넌트에서 `t(context).ink` 처럼 사용.
AppTokens t(BuildContext context) =>
    Theme.of(context).extension<AppTokens>() ?? kThemes.first.tokens;

/// 앱 전역 글자 굵기 delta (설정의 "글자 굵기"). AppTheme.build 에서 갱신.
/// AppText 를 직접 호출하는 위젯들도 이 값을 반영한다.
int appWeightDelta = 0;

/// 라벨·기호·숫자용 글꼴. 기본은 null 로 두어 폰 시스템 글꼴을 따른다.
/// AppTheme.build 에서 갱신.
String? appMono = kSansFamily;

/// 한글 본문·제목 글꼴. 기본은 null 로 두어 폰 시스템 글꼴을 따른다.
/// AppTheme.build 에서 갱신.
String? appSans = kSansFamily;

/// 편집 타이포 (DESIGN_SYSTEM §3).
/// 기본은 폰 시스템 글꼴, 내장 글꼴 모드에서는 선택한 앱 폰트로 전체를 맞춘다.
/// 색은 토큰을 주입.
class AppText {
  /// 화면 타이틀 (한글, Sans 19/Bold).
  static TextStyle hTitle(Color c, [int? wd]) => TextStyle(
      fontFamily: appSans,
      fontSize: 19,
      fontWeight: shiftWeight(FontWeight.w700, wd ?? appWeightDelta),
      height: 1.2,
      letterSpacing: -0.2,
      color: c);

  /// 할 일 제목·본문 (한글, Sans 15/Medium).
  static TextStyle body(Color c, [int? wd]) => TextStyle(
      fontFamily: appSans,
      fontSize: 15,
      fontWeight: shiftWeight(FontWeight.w500, wd ?? appWeightDelta),
      height: 1.4,
      letterSpacing: -0.15,
      color: c);

  /// 섹션 대문자 라벨 (Mono 11/Bold, +0.14em).
  static TextStyle sec(Color c) => TextStyle(
      fontFamily: appMono,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: 1.54,
      color: c);

  /// 우선순위 라벨 (Mono 10, +0.12em).
  static TextStyle pri(Color c, {bool bold = false}) => TextStyle(
      fontFamily: appMono,
      fontSize: 10,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      height: 1,
      letterSpacing: 1.2,
      color: c);

  /// 카운트·날짜·시간·메뉴·빈 상태 (Mono 11, +0.05em).
  static TextStyle meta(Color c, {double size = 11}) => TextStyle(
      fontFamily: appMono,
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: 1.3,
      letterSpacing: 0.55,
      color: c);

  /// 메타(Sans) — 기호(별자리 ♋ 등)처럼 모노에 없을 수 있는 글자 렌더용.
  static TextStyle metaSans(Color c, {double size = 11}) => TextStyle(
      fontFamily: appSans,
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: c);

  /// 하단 탭 (Mono 10 소문자, +0.04em).
  static TextStyle nav(Color c, {bool active = false}) => TextStyle(
      fontFamily: appMono,
      fontSize: 10,
      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
      height: 1,
      letterSpacing: 0.4,
      color: c);

  /// 칩 (Mono 10, +0.08em — 한글 허용).
  static TextStyle chip(Color c) => TextStyle(
      fontFamily: appMono,
      fontSize: 10,
      fontWeight: FontWeight.w400,
      height: 1,
      letterSpacing: 0.8,
      color: c);

  /// 체크박스·기호 글리프 (Mono 15).
  static TextStyle glyph(Color c, {double size = 15}) =>
      TextStyle(fontFamily: appMono, fontSize: size, height: 1, color: c);
}

/// 6토큰 → ThemeData. 편집 원칙(radius 0 · shadow none · 잉크 하나)을 강제한다.
class AppTheme {
  static ThemeData fromKey(String key,
          {int weightDelta = 0,
          bool systemFont = false,
          String fontKey = kDefaultFontKey}) =>
      build(tokensForKey(key),
          weightDelta: weightDelta, systemFont: systemFont, fontKey: fontKey);

  static ThemeData build(AppTokens tk,
      {int weightDelta = 0,
      bool systemFont = false,
      String fontKey = kDefaultFontKey}) {
    appWeightDelta = weightDelta; // 전역 반영 (AppText 직접 호출부용)
    // 시스템 글꼴 사용 시 fontFamily 를 지정하지 않아 폰 기본 글꼴을 따른다.
    // 끄면 앱에 번들된 폰트를 쓰되 라벨·숫자까지 같은 글꼴로 맞춘다.
    appSans = systemFont ? kSansFamily : familyForFontKey(fontKey);
    appMono = appSans;
    final b = tk.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(brightness: b, useMaterial3: true);

    final reg = shiftWeight(FontWeight.w400, weightDelta);
    final med = shiftWeight(FontWeight.w500, weightDelta);
    final bold = shiftWeight(FontWeight.w700, weightDelta);

    final textTheme = TextTheme(
      titleLarge: AppText.hTitle(tk.ink, weightDelta),
      titleMedium: TextStyle(
          fontFamily: appSans,
          fontWeight: bold,
          fontSize: 16,
          letterSpacing: -0.15,
          color: tk.ink),
      bodyLarge: TextStyle(
          fontFamily: appSans,
          fontWeight: med,
          fontSize: 15,
          height: 1.4,
          letterSpacing: -0.15,
          color: tk.ink),
      bodyMedium: AppText.body(tk.ink, weightDelta),
      bodySmall: AppText.meta(tk.inkSoft),
    );

    return base.copyWith(
      scaffoldBackgroundColor: tk.paper,
      canvasColor: tk.paper,
      extensions: [tk],
      // 모든 역할을 잉크/종이 토큰으로 덮는다 — M3 기본(보라) 팔레트가
      // 날짜/시간 피커·컨테이너 등에서 새어나오지 않도록 전부 지정.
      colorScheme: base.colorScheme.copyWith(
        brightness: b,
        primary: tk.ink,
        onPrimary: tk.paper,
        primaryContainer: tk.paper2,
        onPrimaryContainer: tk.ink,
        secondary: tk.inkSoft,
        onSecondary: tk.paper,
        secondaryContainer: tk.paper2,
        onSecondaryContainer: tk.ink,
        tertiary: tk.ink,
        onTertiary: tk.paper,
        tertiaryContainer: tk.paper2,
        onTertiaryContainer: tk.ink,
        surface: tk.paper,
        onSurface: tk.ink,
        surfaceContainerHighest: tk.paper2,
        onSurfaceVariant: tk.inkSoft,
        surfaceTint: Colors.transparent,
        inverseSurface: tk.ink,
        onInverseSurface: tk.paper,
        inversePrimary: tk.paper,
        error: AppState.error,
        onError: tk.paper,
        outline: tk.line,
        outlineVariant: tk.line,
      ),
      // 날짜 피커: 범위 하이라이트·헤더를 편집 톤으로(보라 제거).
      datePickerTheme: DatePickerThemeData(
        backgroundColor: tk.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        headerBackgroundColor: tk.paper,
        headerForegroundColor: tk.ink,
        rangeSelectionBackgroundColor: tk.paper2,
        rangePickerHeaderBackgroundColor: tk.paper,
        rangePickerHeaderForegroundColor: tk.ink,
        rangePickerBackgroundColor: tk.paper,
        rangePickerSurfaceTintColor: Colors.transparent,
        rangePickerElevation: 0,
        todayForegroundColor: WidgetStatePropertyAll(tk.ink),
        todayBorder: BorderSide(color: tk.ink, width: 1),
        dayForegroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? tk.paper : tk.ink),
        dayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? tk.ink : Colors.transparent),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      // 시간 피커: 다이얼·선택 배경도 잉크 톤.
      timePickerTheme: TimePickerThemeData(
        backgroundColor: tk.paper,
        hourMinuteColor: tk.paper2,
        hourMinuteTextColor: tk.ink,
        dialBackgroundColor: tk.paper2,
        dialHandColor: tk.ink,
        dialTextColor: tk.ink,
        dayPeriodColor: tk.paper2,
        dayPeriodTextColor: tk.ink,
        entryModeIconColor: tk.inkSoft,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      textTheme: textTheme,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      iconTheme: IconThemeData(color: tk.ink, size: 20),
      dividerTheme: DividerThemeData(thickness: 1, space: 1, color: tk.line),
      appBarTheme: AppBarTheme(
        backgroundColor: tk.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: tk.ink,
        toolbarHeight: 52,
        titleTextStyle: AppText.hTitle(tk.ink, weightDelta),
      ),
      cardTheme: const CardThemeData(elevation: 0),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: tk.ink,
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(34, 34),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      // 드로어·팝업·다이얼로그·시트: 각지게, 틴트 없이, 1px 규칙선.
      drawerTheme: DrawerThemeData(
        backgroundColor: tk.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tk.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: tk.ink, width: 1),
        ),
      ),
      listTileTheme:
          ListTileThemeData(iconColor: tk.inkSoft, textColor: tk.ink),
      dialogTheme: DialogThemeData(
        backgroundColor: tk.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: tk.ink, width: 1),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tk.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tk.ink,
        contentTextStyle: AppText.body(tk.paper, weightDelta),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        behavior: SnackBarBehavior.floating,
      ),
      // 버튼: 채움 = 잉크 반전, 텍스트 = inkSoft. 각지게.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tk.ink,
          foregroundColor: tk.paper,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle:
              TextStyle(fontFamily: appSans, fontWeight: bold, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tk.inkSoft,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle:
              TextStyle(fontFamily: appSans, fontWeight: reg, fontSize: 14),
        ),
      ),
      // 칩(필터): 각진 1px 규칙선, 선택 시 잉크 반전. 체크 없음.
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: tk.paper,
        selectedColor: tk.ink,
        surfaceTintColor: Colors.transparent,
        showCheckmark: false,
        side: BorderSide(color: tk.line, width: 1),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        labelStyle: AppText.chip(tk.inkSoft),
        secondaryLabelStyle: AppText.chip(tk.paper),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      // 입력: 캐럿 = mark, 밑줄 = 잉크.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tk.mark,
        selectionColor: tk.mark.withValues(alpha: 0.20),
        selectionHandleColor: tk.mark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: AppText.body(tk.inkSoft, weightDelta),
        isDense: true,
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: tk.line, width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: tk.ink, width: 1.5),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: tk.ink,
        inactiveTrackColor: tk.line,
        thumbColor: tk.ink,
        overlayColor: tk.ink.withValues(alpha: 0.12),
        trackHeight: 2,
      ),
    );
  }
}
