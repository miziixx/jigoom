import 'package:flutter/widgets.dart';

import 'studio_tokens.dart';
import 'widget_config.dart';

/// ============================================================
/// WIDGET STUDIO — 스킨 & 타이포 (레퍼런스 CSS 직접 이식)
///
/// 위젯 하나에 대해 테마·오버라이드·글자배율·반응형 상태를 미리 계산한 값 묶음.
/// 레퍼런스의 CSS 커스텀 프로퍼티(--widget-*)와 공용 타이포(.w-title 등)를
/// 그대로 옮겼다. letter-spacing 은 CSS 의 em → px(= em × fontSize) 로 변환.
/// ============================================================
class StudioSkin {
  StudioSkin(this.config, this.theme)
      : font = config.fontScale / 100,
        size = config.sizeState;

  final WidgetConfig config;
  final StudioTheme theme;
  final double font; // --widget-font (fontScale/100)
  final StudioSizeState size;

  bool get isCompact => size != StudioSizeState.normal;
  bool get isTiny => size == StudioSizeState.tiny;

  // --- 색상 (오버라이드 우선) ----------------------------------------------
  Color get ink => theme.ink;
  Color get muted => theme.muted;
  Color get line => config.lineColor != null
      ? Color(config.lineColor!)
      : theme.line;
  Color get primary => config.accentColor != null
      ? Color(config.accentColor!)
      : theme.primary;
  Color get primaryDark => theme.primaryDark;
  Color get primaryWeak => theme.primaryWeak;

  /// 위젯 표면 배경색(알파 포함). surface 종류에 따라 결정.
  Color get surfaceColor {
    switch (config.surface) {
      case StudioSurface.transparent:
        return const Color(0x00000000);
      case StudioSurface.solid:
        return theme.surface;
      case StudioSurface.glass:
      case StudioSurface.paper:
        return theme.surface.withValues(alpha: config.backgroundOpacity / 100);
    }
  }

  double get lineWidth => config.lineWidth;

  // --- 공용 타이포 (레퍼런스) ----------------------------------------------
  // .w-title — serif 17px w500 -.035em
  TextStyle get wTitle => TextStyle(
        fontFamily: StudioFont.serif,
        fontSize: (isCompact ? 13 : 17) * font,
        fontWeight: FontWeight.w500,
        height: 1.15,
        letterSpacing: -0.035 * (isCompact ? 13 : 17) * font,
        color: ink,
      );

  // .w-meta — mono 7.5px /1.45 muted +.06em w500
  TextStyle get wMeta => TextStyle(
        fontFamily: StudioFont.mono,
        fontFamilyFallback: StudioFont.monoFallback,
        fontSize: 7.5 * font,
        fontWeight: FontWeight.w500,
        height: 1.45,
        letterSpacing: 0.06 * 7.5 * font,
        color: muted,
      );

  // .widget-kicker — mono 6.8px /1 +.15em primary w500
  TextStyle get kicker => TextStyle(
        fontFamily: StudioFont.mono,
        fontFamilyFallback: StudioFont.monoFallback,
        fontSize: 6.8 * font,
        fontWeight: FontWeight.w500,
        height: 1,
        letterSpacing: 0.15 * 6.8 * font,
        color: primary,
      );

  // .w-chip — mono 6.8px /1 primary w500 (nowrap)
  TextStyle get chip => TextStyle(
        fontFamily: StudioFont.mono,
        fontFamilyFallback: StudioFont.monoFallback,
        fontSize: 6.8 * font,
        fontWeight: FontWeight.w500,
        height: 1,
        color: primary,
      );

  // .w-row strong — 10px w600 (ellipsis)
  TextStyle get rowStrong => TextStyle(
        fontFamily: StudioFont.sans,
        fontSize: 10 * font,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: ink,
      );

  // .w-row small — 7.2px muted
  TextStyle get rowSmall => TextStyle(
        fontFamily: StudioFont.sans,
        fontSize: 7.2 * font,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: muted,
      );

  /// 임의 크기 mono. size 는 px(배율 미적용) — 호출부에서 * font 하지 않음:
  /// 편의를 위해 여기서 곱한다.
  TextStyle mono(double px,
          {Color? color, double letterEm = 0, FontWeight weight = FontWeight.w500, double height = 1}) =>
      TextStyle(
        fontFamily: StudioFont.mono,
        fontFamilyFallback: StudioFont.monoFallback,
        fontSize: px * font,
        fontWeight: weight,
        height: height,
        letterSpacing: letterEm * px * font,
        color: color ?? muted,
      );

  TextStyle serif(double px,
          {Color? color, FontWeight weight = FontWeight.w500, double height = 1.15, double letterEm = -0.03}) =>
      TextStyle(
        fontFamily: StudioFont.serif,
        fontSize: px * font,
        fontWeight: weight,
        height: height,
        letterSpacing: letterEm * px * font,
        color: color ?? ink,
      );

  TextStyle sans(double px,
          {Color? color, FontWeight weight = FontWeight.w400, double height = 1.35}) =>
      TextStyle(
        fontFamily: StudioFont.sans,
        fontSize: px * font,
        fontWeight: weight,
        height: height,
        color: color ?? ink,
      );
}
