import 'package:flutter/material.dart';

/// 기준 HTML(Reference Merge V5) 재현용 공통 디자인 토큰.
///
/// 기존 에디토리얼 상수([kRadius]=0 등)는 그대로 두고, 곰곰(지금 v2)의
/// 기준 화면들이 함께 참조할 값만 **추가**한다. 색은 기준 HTML의 CSS 변수
/// 값을 그대로 옮겼다(저채도 세이지·슬레이트 블루·말린 장미·황토·플럼·청록).
///
/// 기준 HTML은 라이트/다크(MIDNIGHT)에서 광물(mineral)·강조(accent) 색을
/// 살짝 다르게 정의한다. 여기서는 라이트 기준값을 쓰고, 다크가 필요하면
/// [RefPalette.forDark] 로 밝힌 값을 쓴다.

/// 모서리 반경 — 기준 HTML `--radius:18px`, 카드 16, 작은 카드 14, 타일 11~13,
/// 알약 999. 밀도 compact 는 --radius:14px.
class RefRadius {
  static const double screen = 18; // --radius (veil/큰 카드)
  static const double card = 16; // schedule-card / metric mini
  static const double cardSm = 14; // date-strip / current-stage
  static const double tile = 13; // return-line / time-card
  static const double tile2 = 11; // activity-feed / week-card
  static const double soft = 12; // outline-head / day cell
  static const double pill = 999; // 세그먼트·칩·버튼
}

/// 기준 HTML의 광물(mineral)·강조(accent) 팔레트.
///
/// mineral* = "REFERENCE MERGE V3 COMPLETE" 블록(운세 프리미엄·점 그래프),
/// accent*  = "reference merged v2" 블록(달력 스트림·루틴·습관 노드).
/// soft 변형은 같은 색의 낮은 알파(≈14~18%) 배경.
class RefPalette {
  const RefPalette._();

  // ---- mineral (프리미엄 운세·점수 카드) — 라이트 기준값 ----
  static const Color mineralSage = Color(0xFF6F8B79);
  static const Color mineralBlue = Color(0xFF7389A6);
  static const Color mineralRose = Color(0xFFB57A86);
  static const Color mineralOchre = Color(0xFFA78958);
  static const Color mineralPlum = Color(0xFF88788F);
  static const Color mineralTeal = Color(0xFF638C8B);

  // ---- accent (달력·루틴·습관·아웃라인 leaf-dot) — 라이트 기준값 ----
  static const Color accentSage = Color(0xFF7FAE97);
  static const Color accentBlue = Color(0xFF86A8D4);
  static const Color accentRose = Color(0xFFD68EAA);
  static const Color accentAmber = Color(0xFFD6AF63);
  static const Color accentViolet = Color(0xFFA594CF);
  static const Color accentCyan = Color(0xFF76B8BC);

  // ---- MIDNIGHT(다크)에서 기준 HTML이 밝힌 mineral 값 ----
  static const Color mineralSageDark = Color(0xFF8EAD99);
  static const Color mineralBlueDark = Color(0xFF91A7C8);
  static const Color mineralRoseDark = Color(0xFFC68A97);
  static const Color mineralOchreDark = Color(0xFFB99B66);
  static const Color mineralPlumDark = Color(0xFFA092A8);
  static const Color mineralTealDark = Color(0xFF7AA5A4);

  /// 다크에서는 기준 HTML처럼 살짝 밝힌 mineral 값을 쓴다.
  static Color mineral(String key, {bool dark = false}) {
    switch (key) {
      case 'sage':
        return dark ? mineralSageDark : mineralSage;
      case 'blue':
        return dark ? mineralBlueDark : mineralBlue;
      case 'rose':
        return dark ? mineralRoseDark : mineralRose;
      case 'ochre':
        return dark ? mineralOchreDark : mineralOchre;
      case 'plum':
        return dark ? mineralPlumDark : mineralPlum;
      case 'teal':
        return dark ? mineralTealDark : mineralTeal;
      default:
        return dark ? mineralSageDark : mineralSage;
    }
  }

  static Color accent(String key) {
    switch (key) {
      case 'sage':
        return accentSage;
      case 'blue':
        return accentBlue;
      case 'rose':
        return accentRose;
      case 'amber':
        return accentAmber;
      case 'violet':
        return accentViolet;
      case 'cyan':
        return accentCyan;
      default:
        return accentSage;
    }
  }

  /// 같은 색의 반투명 배경(soft). 기준 HTML의 `*-soft` (알파 ≈0.15).
  static Color soft(Color c, {double alpha = 0.15}) =>
      c.withValues(alpha: alpha);
}

/// 색을 종이 위에 합성 — 기준 HTML `color-mix(in srgb, A pct%, paper)`.
/// = pct·A + (1-pct)·paper. 알파 합성과 동일.
Color mixOver(Color a, double pct, Color paper) =>
    Color.alphaBlend(a.withValues(alpha: pct), paper);

/// 오늘 화면의 일정 카드 저채도 색면(schedule-card 종류별).
/// 기준 HTML `--card-*`: 원색을 종이 위에 17~22% 로 합성한 옅은 색면.
Color scheduleCardTint(String kind, Color paper) {
  switch (kind) {
    case 'study':
      return mixOver(const Color(0xFFE9D96A), 0.18, paper);
    case 'focus':
      return mixOver(const Color(0xFFAFC8F0), 0.22, paper);
    case 'calm':
      return mixOver(const Color(0xFFA9D1C3), 0.19, paper);
    case 'habit':
      return mixOver(const Color(0xFFE8BDD2), 0.20, paper);
    case 'external':
      return mixOver(const Color(0xFFB9C4D6), 0.17, paper);
    default:
      return paper;
  }
}

/// 날짜별 스트림/달력의 종류색(event-dot / day-stream-item).
/// 기준 HTML: 루틴=sage · 할일=amber · 일정=blue · 습관=violet · 메모=rose · 기록=cyan.
Color streamKindColor(String kind) {
  switch (kind) {
    case 'routine':
      return RefPalette.accentSage;
    case 'task':
      return RefPalette.accentAmber;
    case 'schedule':
      return RefPalette.accentBlue;
    case 'habit':
      return RefPalette.accentViolet;
    case 'memo':
      return RefPalette.accentRose;
    case 'record':
      return RefPalette.accentCyan;
    default:
      return RefPalette.accentSage;
  }
}

/// 습관 대표 노드 크기(px) — 최근 30일 실행 횟수 기준. (기준 프롬프트 4단계·습관)
/// 0회=4 · 1~3=5 · 4~7=6 · 8~15=8 · 16~23=10 · 24회↑=12.
double habitNodeSize(int count) {
  if (count <= 0) return 4;
  if (count <= 3) return 5;
  if (count <= 7) return 6;
  if (count <= 15) return 8;
  if (count <= 23) return 10;
  return 12;
}

/// 루틴 라이브러리 빈도 노드 크기(px) — 기준 HTML `sizeFor(count)`.
/// ≤3=6 · ≤7=7 · ≤15=9 · ≤23=11 · 그 외 14.
double routineNodeSize(int count) {
  if (count <= 3) return 6;
  if (count <= 7) return 7;
  if (count <= 15) return 9;
  if (count <= 23) return 11;
  return 14;
}
