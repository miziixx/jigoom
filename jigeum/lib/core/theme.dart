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

/// 내장 11종 — 9 라이트 + 2 다크(NOIR · INK NIGHT). 기본 SAGE. (DESIGN_SYSTEM §1-1)
const List<ThemeSpec> kThemes = [
  // ─────────────────────────────────────────────────────────────────────
  // 곰곰 리디자인 팔레트 (v4 시안). mark = '지금·살아있음' 앰버 포인트.
  // 채운 버튼은 기존대로 ink(웜 액션) — 파란색 없음.
  // ─────────────────────────────────────────────────────────────────────
  // 곰곰 — 웜 포슬린 종이 + 에스프레소 잉크 + 앰버 포인트 (기본).
  ThemeSpec(
      'gomgom',
      '곰곰',
      AppTokens(
          paper: Color(0xFFEAE4D9),
          paper2: Color(0xFFE2DBCD),
          ink: Color(0xFF231E18),
          inkSoft: Color(0xFF897F70),
          line: Color(0xFFDAD2C3),
          mark: Color(0xFFD6852A))),
  // 라벤더 버터 — 연보라 종이 + 버터 앰버 포인트.
  ThemeSpec(
      'lavender',
      '라벤더 버터',
      AppTokens(
          paper: Color(0xFFECE5EF),
          paper2: Color(0xFFE4DBEA),
          ink: Color(0xFF2E2733),
          inkSoft: Color(0xFF8A8092),
          line: Color(0xFFDCD3E3),
          mark: Color(0xFFD79E3B))),
  // 세이지 안개 — 세이지 크림 + 클레이 포인트.
  ThemeSpec(
      'sagemist',
      '세이지 안개',
      AppTokens(
          paper: Color(0xFFE7E9DE),
          paper2: Color(0xFFDEE1D3),
          ink: Color(0xFF2B322A),
          inkSoft: Color(0xFF7C8377),
          line: Color(0xFFD6DACB),
          mark: Color(0xFFC4794A))),
  // 코스탈 방갈로 — 모래 크림 + 샌드 테라코타 포인트.
  ThemeSpec(
      'coastal',
      '코스탈 방갈로',
      AppTokens(
          paper: Color(0xFFF1EADF),
          paper2: Color(0xFFE8DFCF),
          ink: Color(0xFF3A2C20),
          inkSoft: Color(0xFF8C7C68),
          line: Color(0xFFE0D4C1),
          mark: Color(0xFFC1854E))),
  // 블러시 코니 — 블러시 크림 + 로즈 클레이 포인트.
  ThemeSpec(
      'blush',
      '블러시 코니',
      AppTokens(
          paper: Color(0xFFF3E7E4),
          paper2: Color(0xFFEBD9D6),
          ink: Color(0xFF33272A),
          inkSoft: Color(0xFF907E82),
          line: Color(0xFFE7D6D3),
          mark: Color(0xFFD08A6A))),
  // 연꽃 못 · 밤 — 딥 그린 다크 + 로지 포인트. paper 어두워 자동 Brightness.dark.
  ThemeSpec(
      'lotus',
      '연꽃 못 · 밤',
      AppTokens(
          paper: Color(0xFF102A22),
          paper2: Color(0xFF1B392F),
          ink: Color(0xFFF0EAD6),
          inkSoft: Color(0xFF9FB3A2),
          line: Color(0xFF28453A),
          mark: Color(0xFFDDA08F))),
  // ─────────────────────────────────────────────────────────────────────
  // MANILA — 기준 HTML `html[data-theme="manila"]` 정밀값.
  ThemeSpec(
      'manila',
      'MANILA',
      AppTokens(
          paper: Color(0xFFFBF8F0), // --paper
          paper2: Color(0xFFECE3D4), // --surface-2
          ink: Color(0xFF332F28), // --ink
          inkSoft: Color(0xFF82786A), // --muted
          line: Color(0xFFE1DCD2), // --line(합성)
          mark: Color(0xFF776C54))), // --node
  // NEWSPRINT — 기준 HTML `html[data-theme="newsprint"]` 정밀값.
  ThemeSpec(
      'newsprint',
      'NEWSPRINT',
      AppTokens(
          paper: Color(0xFFF2F3EF), // --paper
          paper2: Color(0xFFE2E3DE), // --surface-2
          ink: Color(0xFF1F231F), // --ink
          inkSoft: Color(0xFF717670), // --muted
          line: Color(0xFFCECFCB), // --line(합성)
          mark: Color(0xFF2F3430))), // --node
  // SAGE — 기준 HTML(Reference Merge V5) 정밀 팔레트. 6토큰을 기준값에 맞춤:
  // paper=--paper #F7F8F4 · paper2=--surface-2 #E8ECE6 · ink=--ink #263029 ·
  // inkSoft=--muted #778179 · line=--line rgba(61,79,68,.17) 을 종이 위에 합성한 #D7DCD6 ·
  // mark=--node(세이지 포인트) #607D6C.
  ThemeSpec(
      'sage',
      'SAGE',
      AppTokens(
          paper: Color(0xFFF7F8F4), // --paper
          paper2: Color(0xFFE8ECE6), // --surface-2
          ink: Color(0xFF263029), // --ink
          inkSoft: Color(0xFF778179), // --muted
          line: Color(0xFFD7DCD6), // --line (합성값)
          mark: Color(0xFF607D6C))), // --node
  // MIDNIGHT — 기준 HTML `html[data-theme="midnight"]` 진짜 다크(#0C1220 계열).
  // paper 이 어두워 isDark=true → 앱이 자동으로 Brightness.dark 로 빌드된다.
  // (별도 다크 NOIR·INK NIGHT 는 그대로 유지 — 삭제 없음.)
  ThemeSpec(
      'midnight',
      'MIDNIGHT',
      AppTokens(
          paper: Color(0xFF11192A), // --paper
          paper2: Color(0xFF202C43), // --surface-2
          ink: Color(0xFFEFF2EE), // --ink
          inkSoft: Color(0xFF9CA8A4), // --muted
          line: Color(0xFF2C3543), // --line(합성)
          mark: Color(0xFF9AB2A6))), // --node
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
  // INK NIGHT — 검정이 아닌 잉크색 다크. 따뜻한 회백색 텍스트 + 낮은 채도
  // 세이지 포인트. 6토큰에 매핑: paper=배경, paper2=서피스, ink=본문,
  // inkSoft=메타(가독 유지), line=아주 얇은 헤어라인(투명 14%), mark=세이지.
  ThemeSpec(
      'inknight',
      'INK NIGHT',
      AppTokens(
          paper: Color(0xFF141613),
          paper2: Color(0xFF1B1E1A),
          ink: Color(0xFFF0EEE7),
          inkSoft: Color(0xFFB5B7AF),
          line: Color(0x24F0EEE7),
          mark: Color(0xFF9AAA91))),
];

const String kDefaultThemeKey = 'gomgom';

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

/// 라벨·기호·숫자용 글꼴. 레퍼런스처럼 라틴/숫자는 모노스페이스로 —
/// 한글 등 모노에 없는 글자는 [appMonoFallback] 로 렌더. AppTheme.build 에서 갱신.
String? appMono = kSerifFamily;

/// 명조 통일: 모노 폴백 없음(세리프가 라틴·한글·한자 모두 렌더).
List<String> appMonoFallback = const <String>[];

/// 한글 본문·제목 글꼴. 명조(세리프)로 통일. AppTheme.build 에서 갱신.
String? appSans = kSerifFamily;

/// 제목/헤딩 글꼴. systemFont 켜면 폰 기본 글꼴(null)로, 끄면 명조. AppTheme.build 에서 갱신.
String? appSerif = kSerifFamily;

/// 편집 타이포 (DESIGN_SYSTEM §3).
/// 기본은 폰 시스템 글꼴, 내장 글꼴 모드에서는 선택한 앱 폰트로 전체를 맞춘다.
/// 색은 토큰을 주입.
class AppText {
  /// 화면 타이틀 (한글, 세리프/명조 19/Medium). v17 에디토리얼 — 얇은 세리프.
  static TextStyle hTitle(Color c, [int? wd]) => TextStyle(
      fontFamily: appSerif,
      fontSize: 17,
      fontWeight: shiftWeight(FontWeight.w500, wd ?? appWeightDelta),
      height: 1.2,
      letterSpacing: -0.4,
      color: c);

  /// 임의 크기 세리프 헤딩 (제목·큰 숫자·목표). v17 시그니처.
  static TextStyle serif(Color c,
          {double size = 22,
          FontWeight weight = FontWeight.w500,
          double height = 1.2,
          double? letterSpacing,
          int? wd}) =>
      TextStyle(
          fontFamily: appSerif,
          fontSize: size,
          // 전역 굵기(systemFont 시 −1)를 제목·섹션 헤더도 따르게 한다.
          fontWeight: shiftWeight(weight, wd ?? appWeightDelta),
          height: height,
          letterSpacing: letterSpacing ?? -size * 0.03,
          color: c);

  /// 할 일 제목·본문 (한글, Sans 15/Medium).
  static TextStyle body(Color c, [int? wd]) => TextStyle(
      fontFamily: appSans,
      // 레퍼런스 편집 타이포: 본문/할 일은 작고 가볍게(명조 Regular 400).
      fontSize: 12,
      fontWeight: shiftWeight(FontWeight.w400, wd ?? appWeightDelta),
      height: 1.42,
      letterSpacing: -0.2,
      color: c);

  /// 섹션 대문자 라벨 (Mono 11/Bold, +0.14em).
  static TextStyle sec(Color c) => TextStyle(
      fontFamily: appMono,
      fontFamilyFallback: appMonoFallback,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: 1.54,
      color: c);

  /// 우선순위 라벨 (Mono 10, +0.12em).
  static TextStyle pri(Color c, {bool bold = false}) => TextStyle(
      fontFamily: appMono,
      fontFamilyFallback: appMonoFallback,
      fontSize: 10,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      height: 1,
      letterSpacing: 1.2,
      color: c);

  /// 카운트·날짜·시간·메뉴·빈 상태 (Mono 11, +0.05em).
  static TextStyle meta(Color c, {double size = 11}) => TextStyle(
      fontFamily: appMono,
      fontFamilyFallback: appMonoFallback,
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
      fontFamilyFallback: appMonoFallback,
      fontSize: 10,
      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
      height: 1,
      letterSpacing: 0.4,
      color: c);

  /// 칩 (Mono 10, +0.08em — 한글 허용).
  static TextStyle chip(Color c) => TextStyle(
      fontFamily: appMono,
      fontFamilyFallback: appMonoFallback,
      fontSize: 10,
      fontWeight: FontWeight.w400,
      height: 1,
      letterSpacing: 0.8,
      color: c);

  /// 체크박스·기호 글리프 (Mono 15).
  static TextStyle glyph(Color c, {double size = 15}) => TextStyle(
      fontFamily: appMono,
      fontFamilyFallback: appMonoFallback,
      fontSize: size,
      height: 1,
      color: c);
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
    // 곰곰: systemFont 켜면(기본) 본문·제목·라벨 전부 폰 기본 글꼴로 —
    // 번들 명조/Pretendard 강제 없음. 끄면 에디토리얼(Pretendard 본문 + 명조 제목).
    //  · 본문(sans)  = systemFont? 폰 기본 : Pretendard
    //  · 제목(serif) = systemFont? 폰 기본 : 명조(NanumMyeongjo)
    //  · 라벨(mono)  = 모노스페이스(폰 기본 고정폭), 번들 모드만 Pretendard 폴백
    appSans = systemFont ? kSansFamily : 'Pretendard';
    appMono = kMonoFamily;
    appMonoFallback = systemFont ? const <String>[] : const ['Pretendard'];
    appSerif = systemFont ? kSansFamily : kSerifFamily;
    // 시스템 산세리프는 같은 굵기라도 명조/Pretendard 보다 두껍게 보인다 →
    // systemFont 일 때 전체를 한 단계 가늘게(−1) 낮춰 균형을 맞춘다.
    final wDelta = weightDelta + (systemFont ? -1 : 0);
    appWeightDelta = wDelta; // 전역 반영 (AppText 직접 호출부용)
    final b = tk.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(brightness: b, useMaterial3: true);

    final reg = shiftWeight(FontWeight.w400, wDelta);
    final med = shiftWeight(FontWeight.w500, wDelta);
    final bold = shiftWeight(FontWeight.w700, wDelta);

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
        // 레퍼런스 v17 .modal — .75px 잉크 테두리 + radius 5.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: tk.ink, width: 0.75),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tk.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // 레퍼런스 v17 .sheet — 상단 모서리 radius 8.
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
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
      // 입력: 캐럿 = mark. 레퍼런스 .field input — 박스(line 테두리) + radius 6.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tk.mark,
        selectionColor: tk.mark.withValues(alpha: 0.20),
        selectionHandleColor: tk.mark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: AppText.body(tk.inkSoft, weightDelta),
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: tk.line, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
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
