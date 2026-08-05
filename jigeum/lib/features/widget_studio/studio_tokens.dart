import 'package:flutter/widgets.dart';

/// ============================================================
/// WIDGET STUDIO — 디자인 토큰 (단일 시각 명세)
///
/// 레퍼런스: design-reference/jigeum_widget_studio_editorial_v2.html
/// 모든 값은 그 HTML의 CSS/JS 에서 **직접 추출**한 것이다. 눈대중으로 바꾸지 말 것.
///
/// 폰트 매핑 (레퍼런스 CSS 스택 → 앱 번들 폰트). 확인 결과 pubspec.yaml 에
/// 번들된 계열은 Pretendard · NanumGothic · GowunDodum · NanumMyeongjo ·
/// NotoSerifKR 뿐이고 **전용 모노스페이스 폰트는 번들돼 있지 않다.**
///   · 산세리프  -apple-system,…,"Noto Sans KR"  → 'Pretendard' (번들 ✅)
///   · 에디토리얼 Georgia,"Noto Serif KR",serif    → 'NotoSerifKR' (번들 ✅)
///   · 모노      ui-monospace,SFMono,Menlo         → 'monospace' (플랫폼 제네릭)
///        JetBrainsMono/SFMono 등은 번들돼 있지 않아 임의 유료 폰트를 추가하지
///        않고, 앱이 이미 라벨·숫자에 쓰는 시스템 제네릭 'monospace'(안드로이드
///        Roboto Mono 계열)로 대체한다. 한글은 [monoFallback] 로 렌더.
///   · 시계 숫자 "Helvetica Neue","Segoe UI"        → 'Pretendard' Light(가장 가까움)
/// 이 매핑은 결과 보고서 §6 에 그대로 명시한다.
/// ============================================================
class StudioFont {
  StudioFont._();
  static const sans = 'Pretendard'; // -apple-system … Noto Sans KR
  static const serif = 'NotoSerifKR'; // Georgia · Noto Serif KR
  static const mono = 'monospace'; // ui-monospace · SFMono · Menlo (제네릭 대체)
  // 모노에 없는 한글/한자는 명조로 폴백해 잘리지 않게 한다.
  static const List<String> monoFallback = ['NanumMyeongjo'];
  // 시계 숫자: 레퍼런스는 Helvetica Neue. 앱엔 없어 Pretendard Light 로 대체(가장 가까움).
  static const clock = 'Pretendard';
}

/// 기준 캔버스 (레퍼런스 .wallpaper).
class StudioCanvas {
  StudioCanvas._();
  static const Size base = Size(390, 844); // 기본 미리보기
  static const Size large = Size(430, 932); // 대형
  static const double radius = 32; // .wallpaper border-radius
  static const double gridStep = 24; // .wallpaper-grid 반복 24px
  static const double gridOpacity = 0.13;
}

/// 위젯 공통 프레임 상수 (.widget). 레퍼런스 값 그대로.
class StudioFrame {
  StudioFrame._();
  static const double bgAlpha = 0.92; // --widget-bg-alpha
  static const double radius = 14; // --widget-radius
  static const double lineWidth = 0.7; // --widget-line-width
  static const double minWidth = 110; // min-width
  static const double minHeight = 72; // min-height
  static const double headerHeight = 27; // .widget-header height
  // .widget-body padding: 5px 11px 11px (top, LR, bottom)
  static const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(11, 5, 11, 11);
  static const EdgeInsets headerPadding = EdgeInsets.fromLTRB(10, 7, 10, 0);

  // box-shadow: 0 10px 30px rgba(33,35,32,.08)
  static const Color shadowColor = Color(0x14212320); // rgba(33,35,32,.08)
  static const double shadowBlur = 30;
  static const Offset shadowOffset = Offset(0, 10);

  // glass: backdrop blur(16px) saturate(1.04); shadow 0 12px 34px rgba(33,35,32,.09)
  static const double glassBlur = 16;
  static const Color glassShadowColor = Color(0x17212320); // .09
  static const double glassShadowBlur = 34;
  static const Offset glassShadowOffset = Offset(0, 12);

  // .resize-handle 19x19; 선택 아웃라인 1.5px + offset 3
  static const double resizeHandle = 19;
  static const double selectOutline = 1.5;
  static const double selectOutlineOffset = 3;
}

/// 위젯 종류.
enum StudioWidgetType { clock, calendar, goal, tracker, tasks, habits, matrix, capture, fortune }

extension StudioWidgetTypeX on StudioWidgetType {
  String get id => name;
  /// 위젯 헤더 키커(모노 대문자).
  String get kicker => switch (this) {
        StudioWidgetType.clock => 'CLOCK',
        StudioWidgetType.calendar => 'CALENDAR',
        StudioWidgetType.goal => 'GOAL',
        StudioWidgetType.tracker => 'TRACKER',
        StudioWidgetType.tasks => 'TO-DO',
        StudioWidgetType.habits => 'HABITS',
        StudioWidgetType.matrix => 'MATRIX',
        StudioWidgetType.capture => 'CAPTURE',
        StudioWidgetType.fortune => 'FORTUNE',
      };
  String get label => switch (this) {
        StudioWidgetType.clock => '시계',
        StudioWidgetType.calendar => '캘린더',
        StudioWidgetType.goal => '오늘의 목표',
        StudioWidgetType.tracker => '타임트래커',
        StudioWidgetType.tasks => '오늘 할 일',
        StudioWidgetType.habits => '습관',
        StudioWidgetType.matrix => '아이젠하워 매트릭스',
        StudioWidgetType.capture => '빠른 입력',
        StudioWidgetType.fortune => '오늘의 운세',
      };
}

/// 위젯별 기본 크기 (레퍼런스 defaultWidgetSizes). 오차 0px.
const Map<StudioWidgetType, Size> kDefaultWidgetSizes = {
  StudioWidgetType.clock: Size(220, 150),
  StudioWidgetType.calendar: Size(354, 230),
  StudioWidgetType.goal: Size(354, 100),
  StudioWidgetType.tracker: Size(354, 224),
  StudioWidgetType.tasks: Size(220, 210),
  StudioWidgetType.habits: Size(220, 180),
  StudioWidgetType.matrix: Size(354, 230),
  StudioWidgetType.capture: Size(144, 88),
  StudioWidgetType.fortune: Size(220, 130),
};

/// 크기 프리셋 (레퍼런스). 선택 후에도 자유 리사이즈 가능.
const List<({String label, Size size})> kSizePresets = [
  (label: '1 × 1', size: Size(144, 88)),
  (label: '2 × 1', size: Size(220, 100)),
  (label: '2 × 2', size: Size(220, 168)),
  (label: '4 × 1', size: Size(354, 112)),
  (label: '4 × 2', size: Size(354, 184)),
  (label: '4 × 3', size: Size(354, 270)),
];

/// 반응형 상태 — 크기에 따라 자동 전환 (레퍼런스 규칙 그대로).
enum StudioSizeState { normal, compact, tiny }

StudioSizeState studioStateFor(double width, double height) {
  if (width < 160 || height < 90) return StudioSizeState.tiny;
  if (width < 230 || height < 125) return StudioSizeState.compact;
  return StudioSizeState.normal;
}

/// 표면 스타일.
enum StudioSurface { glass, paper, solid, transparent }

/// 조절 범위 (레퍼런스 §13).
class StudioRange {
  StudioRange._();
  static const bgOpacity = (min: 0.0, max: 100.0); // %
  static const opacity = (min: 20.0, max: 100.0); // %
  static const radius = (min: 0.0, max: 30.0); // px
  static const lineWidth = (min: 0.0, max: 3.0); // px
  static const fontScale = (min: 75.0, max: 135.0); // %
}

/// 스튜디오 테마 — 레퍼런스 themes 객체에서 직접 읽은 8종. 색상 동일.
class StudioTheme {
  const StudioTheme({
    required this.key,
    required this.label,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.primary,
    required this.primaryDark,
    required this.primaryWeak,
    required this.wallA,
    required this.wallB,
  });

  final String key;
  final String label;
  final Color bg, surface, surface2, ink, muted, line;
  final Color primary, primaryDark, primaryWeak;
  final Color wallA, wallB; // wallpaper gradient stops

  // 앱 본체(지금)와 1:1 통일된 에디토리얼 테마 — 종이·잉크는 앱 기본 팔레트
  // 그대로, 포인트는 새싹 초록. 홈 위젯 기본값으로 쓴다.
  static const editorial = StudioTheme(
      key: 'editorial', label: '지금 · 에디토리얼',
      bg: Color(0xFFF4F1EA), surface: Color(0xFFFBF9F3), surface2: Color(0xFFEFEBE2),
      ink: Color(0xFF26241F), muted: Color(0xFF9A948A), line: Color(0xFFE5E1D7),
      primary: Color(0xFF4E6659), primaryDark: Color(0xFF34473D), primaryWeak: Color(0xFFE2E8E2),
      wallA: Color(0xFFECE8DE), wallB: Color(0xFFDAD3C4));
  static const sage = StudioTheme(
      key: 'sage', label: 'SOFT SAGE',
      bg: Color(0xFFF5F3EE), surface: Color(0xFFFFFEFB), surface2: Color(0xFFF0EEE7),
      ink: Color(0xFF282A27), muted: Color(0xFF74766F), line: Color(0xFFD8D5CC),
      primary: Color(0xFF4E6659), primaryDark: Color(0xFF34473D), primaryWeak: Color(0xFFE1E9E4),
      wallA: Color(0xFFE8EBE8), wallB: Color(0xFFCFD7D0));
  static const manila = StudioTheme(
      key: 'manila', label: 'MANILA',
      bg: Color(0xFFF7F2E9), surface: Color(0xFFFFFDF8), surface2: Color(0xFFF1E8DA),
      ink: Color(0xFF2A2620), muted: Color(0xFF756C61), line: Color(0xFFE2D8C9),
      primary: Color(0xFFB66C4F), primaryDark: Color(0xFF7D4534), primaryWeak: Color(0xFFF0DDD4),
      wallA: Color(0xFFEFE6D8), wallB: Color(0xFFD8C7B4));
  static const mauve = StudioTheme(
      key: 'mauve', label: 'MAUVE',
      bg: Color(0xFFF3F0F4), surface: Color(0xFFFFFCFF), surface2: Color(0xFFEDE7ED),
      ink: Color(0xFF2E2730), muted: Color(0xFF776D78), line: Color(0xFFDED6DE),
      primary: Color(0xFF8D657A), primaryDark: Color(0xFF604454), primaryWeak: Color(0xFFEADDE5),
      wallA: Color(0xFFE9E3EA), wallB: Color(0xFFD4C6D0));
  static const moss = StudioTheme(
      key: 'moss', label: 'MOSS',
      bg: Color(0xFFF3F4F1), surface: Color(0xFFFEFFFC), surface2: Color(0xFFEAEEE7),
      ink: Color(0xFF262A25), muted: Color(0xFF6E756A), line: Color(0xFFDCE2D8),
      primary: Color(0xFF69735F), primaryDark: Color(0xFF46503F), primaryWeak: Color(0xFFE1E7DC),
      wallA: Color(0xFFE3E7DF), wallB: Color(0xFFCAD1C4));
  static const cobalt = StudioTheme(
      key: 'cobalt', label: 'COBALT',
      bg: Color(0xFFF1F4F7), surface: Color(0xFFFCFEFF), surface2: Color(0xFFE7EDF3),
      ink: Color(0xFF202833), muted: Color(0xFF65707C), line: Color(0xFFD5DEE7),
      primary: Color(0xFF436B92), primaryDark: Color(0xFF294B6D), primaryWeak: Color(0xFFDCE8F2),
      wallA: Color(0xFFE0E9F0), wallB: Color(0xFFBBCDDD));
  static const rose = StudioTheme(
      key: 'rose', label: 'DUSTY ROSE',
      bg: Color(0xFFF7F1F2), surface: Color(0xFFFFFDFD), surface2: Color(0xFFF0E4E7),
      ink: Color(0xFF302629), muted: Color(0xFF77696D), line: Color(0xFFE3D6DA),
      primary: Color(0xFF9A6170), primaryDark: Color(0xFF6E3E4B), primaryWeak: Color(0xFFEEDCE2),
      wallA: Color(0xFFEFE0E4), wallB: Color(0xFFD8C0C7));
  static const ochre = StudioTheme(
      key: 'ochre', label: 'OCHRE',
      bg: Color(0xFFF8F3E8), surface: Color(0xFFFFFDF7), surface2: Color(0xFFF2E9D7),
      ink: Color(0xFF312B21), muted: Color(0xFF786F60), line: Color(0xFFE5DBC7),
      primary: Color(0xFFA47735), primaryDark: Color(0xFF704E20), primaryWeak: Color(0xFFF1E2C5),
      wallA: Color(0xFFF0E6D1), wallB: Color(0xFFDCC99F));
  // 주의: 인스턴스 색상 필드 `ink` 와 이름이 겹치면 안 되므로 상수명은 inkNight.
  static const inkNight = StudioTheme(
      key: 'ink', label: 'INK NIGHT',
      bg: Color(0xFF191B1D), surface: Color(0xFF25282A), surface2: Color(0xFF2E3235),
      ink: Color(0xFFF0F1ED), muted: Color(0xFFA8ADA9), line: Color(0xFF454A4D),
      primary: Color(0xFF8BA99B), primaryDark: Color(0xFFC2D8CE), primaryWeak: Color(0xFF34473F),
      wallA: Color(0xFF252A2D), wallB: Color(0xFF111315));

  static const all = [
    editorial, sage, manila, mauve, moss, cobalt, rose, ochre, inkNight
  ];
  static StudioTheme byKey(String k) =>
      all.firstWhere((t) => t.key == k, orElse: () => editorial);
}
