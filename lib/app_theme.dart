import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// All mutable — updated together by applyColors()
Color kBg = const Color(0xFFEDF2ED);
Color kText = const Color(0xFF556B2F);
Color kSurface = const Color(0xFFE0E8E0);
Color kBorder = const Color(0xFFB0C4B0);
Color kDim = const Color(0xFF7A8F5A);

// Accent colors — mutable, derived from kText via applyColors()
Color kMint = const Color(0xFF6E9530);
Color kTeal = const Color(0xFF527A22);

// ── v3 design tokens ─────────────────────────────────────────────────────────
// Independent accent (kAccent). Initialized to v3 Default amber.
// applyColorsV3() sets this independently; applyColors() mirrors kMint.
Color kAccent = const Color(0xFFB8882A);

// Background steps (bg2..bg5) — lighter in dark mode, darker in light mode.
Color kBg2 = const Color(0xFF141210);
Color kBg3 = const Color(0xFF1A1815);
Color kBg4 = const Color(0xFF201E18);
Color kBg5 = const Color(0xFF262420);

// Text steps (text2..text4) — progressively dimmed toward background.
Color kText2 = const Color(0xFFA09880);
Color kText3 = const Color(0xFF5A5445);
Color kText4 = const Color(0xFF302E26);

// Timeline tokens — derived from bg brightness.
Color kTlLine = const Color(0x12FFFFFF); // rgba(255,255,255,0.07)
Color kTlDot  = const Color(0x1FFFFFFF); // rgba(255,255,255,0.12)

// Font options (Google Fonts + system fonts)
const kFontOptions = [
  'JetBrains Mono',
  'Fira Code',
  'Source Code Pro',
  'Roboto Mono',
  'Space Mono',
  'Nanum Gothic Coding',
];

String kFontFamily = 'JetBrains Mono';
double kFontSize = 13.0;
double kSpacing = 12.0;

const kSpacingOptions = [0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0];

// Typography scale — spec values passed to mono(fontSize: ts*)
// mono() applies kFontSize/13 ratio, so all levels scale together with the slider.
const double tsDisplay = 15.0; // 큰 제목  (base+2)
const double tsHeading = 14.0; // 제목급   (base+1)
const double tsBody    = 13.0; // 본문     (base)
const double tsAlt     = 12.0; // 댓글, 날짜헤더, Today (base-1)
const double tsSmall   = 11.0; // 태그, 링크 (base-2)
const double tsMeta    = 10.0; // 메타정보 (base-3)
const double tsTiny    =  9.0; // 작은 보조 (base-4)

final themeNotifier = ValueNotifier<int>(0);

enum AppThemeMode { normal, dos, minimal }

extension AppThemeModeX on AppThemeMode {
  String get storageValue => switch (this) {
    AppThemeMode.dos => 'dos',
    AppThemeMode.minimal => 'minimal',
    AppThemeMode.normal => 'normal',
  };

  String get label => switch (this) {
    AppThemeMode.dos => 'DOS',
    AppThemeMode.minimal => 'MINIMAL',
    AppThemeMode.normal => '기본',
  };

  static AppThemeMode parse(String? raw) => switch (raw) {
    'dos' => AppThemeMode.dos,
    'minimal' => AppThemeMode.minimal,
    _ => AppThemeMode.normal,
  };
}

final appThemeModeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.normal);

bool get isDosTheme => appThemeModeNotifier.value == AppThemeMode.dos;
bool get isMinimalTheme => appThemeModeNotifier.value == AppThemeMode.minimal;

void applyAppThemeMode(AppThemeMode mode) {
  appThemeModeNotifier.value = mode;
  if (mode == AppThemeMode.dos) {
    const bg  = Color(0xFF000000);
    const fg  = Color(0xFF00FF66);
    const ac  = Color(0xFF00FF66);
    kBg     = bg;
    kSurface = const Color(0xFF050505);
    kText   = fg;
    kDim    = const Color(0xFF00A844);
    kBorder = const Color(0xFF00CC55);
    kMint   = ac;
    kTeal   = const Color(0xFF66FF99);
    kFontFamily = 'JetBrains Mono';
    _deriveV3Tokens(bg, fg, ac);
  }
  themeNotifier.value++;
  syncSystemUiOverlay();
}

// ── v3 token derivation ───────────────────────────────────────────────────────
// Mirrors the JS deriveTokens() in logroom-v3-2.html.
void _deriveV3Tokens(Color bg, Color text, Color accent) {
  final lum = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b;
  final dark = lum < 0.5;
  final lift = dark ? 8 / 255.0 : -6 / 255.0;

  Color step(Color c, int n) => Color.fromARGB(
    255,
    (c.r * 255 + lift * 255 * n).clamp(0, 255).round(),
    (c.g * 255 + lift * 255 * n).clamp(0, 255).round(),
    (c.b * 255 + lift * 255 * n).clamp(0, 255).round(),
  );

  kBg2 = step(bg, 1);
  kBg3 = step(bg, 2);
  kBg4 = step(bg, 3);
  kBg5 = step(bg, 4);

  kText2 = Color.lerp(text, bg, 0.42)!;
  kText3 = Color.lerp(text, bg, 0.68)!;
  kText4 = Color.lerp(text, bg, 0.85)!;

  kAccent = accent;

  kTlLine = dark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.09);
  kTlDot = dark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.black.withValues(alpha: 0.18);
}

// Preferred v3 function — takes independent accent color.
void applyColorsV3(Color bg, Color text, Color accent) {
  kBg = bg;
  kText = text;
  kSurface = Color.lerp(bg, Colors.black, 0.05)!;
  kBorder = Color.lerp(bg, text, 0.35)!;
  kDim = Color.lerp(text, bg, 0.25)!;
  kMint = accent;
  kTeal = Color.lerp(accent, Colors.black, 0.15)!;
  _deriveV3Tokens(bg, text, accent);
  themeNotifier.value++;
  syncSystemUiOverlay();
}

// Legacy 2-arg form — unchanged signature, now also updates v3 tokens.
// Accent mirrors kText (old behavior preserved).
void applyColors(Color bg, Color text) {
  kBg = bg;
  kText = text;
  kSurface = Color.lerp(bg, Colors.black, 0.05)!;
  kBorder = Color.lerp(bg, text, 0.35)!;
  kDim = Color.lerp(text, bg, 0.25)!;
  kMint = text;
  kTeal = Color.lerp(text, Colors.black, 0.15)!;
  _deriveV3Tokens(bg, text, text); // accent = text (legacy)
  themeNotifier.value++;
  syncSystemUiOverlay();
}

void applyLogroomFinalDefaults() {
  // v3 Default preset: bg #0c0b09 / fg #ede8df / ac #b8882a
  applyColorsV3(
    const Color(0xFF0C0B09),
    const Color(0xFFEDE8DF),
    const Color(0xFFB8882A),
  );
}

void syncSystemUiOverlay() {
  // Determine if background is dark so we can pick appropriate icon brightness
  final brightness = ThemeData.estimateBrightnessForColor(kBg);
  final iconBrightness = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: brightness,
      systemNavigationBarColor: kBg,
      systemNavigationBarIconBrightness: iconBrightness,
    ),
  );
}

void applyFont(String family, double size) {
  kFontFamily = family;
  kFontSize = size;
  themeNotifier.value++;
}

void applySpacing(double value) {
  kSpacing = value;
  themeNotifier.value++;
}

double appSpace(double value) => value * (kSpacing / 12.0);

EdgeInsets appInsetsAll(double value) => EdgeInsets.all(appSpace(value));

EdgeInsets appInsetsSymmetric({double horizontal = 0, double vertical = 0}) =>
    EdgeInsets.symmetric(
      horizontal: appSpace(horizontal),
      vertical: appSpace(vertical),
    );

EdgeInsets appInsetsOnly({
  double left = 0,
  double top = 0,
  double right = 0,
  double bottom = 0,
}) => EdgeInsets.only(
  left: appSpace(left),
  top: appSpace(top),
  right: appSpace(right),
  bottom: appSpace(bottom),
);

TextStyle mono({
  Color? color,
  double fontSize = 13,
  FontWeight fontWeight = FontWeight.normal,
  double? letterSpacing,
  double? height,
}) {
  final c = color ?? kText;
  final sz = fontSize * (kFontSize / 13.0);
  // Fonts are bundled as assets (see pubspec.yaml). Reference the family
  // directly so it works offline in release APKs — no runtime download.
  return TextStyle(
    fontFamily: kFontFamily,
    color: c,
    fontSize: sz,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );
}

TextTheme _buildTextTheme(ThemeData base) {
  // All font options are bundled assets — apply the family directly.
  return base.textTheme.apply(fontFamily: kFontFamily);
}

ThemeData buildTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    colorScheme: ColorScheme.dark(
      primary: kMint,
      secondary: kTeal,
      surface: kSurface,
    ),
    textTheme: _buildTextTheme(base),
    dialogTheme: DialogThemeData(backgroundColor: kSurface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: kBorder),
        borderRadius: BorderRadius.zero,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: kBorder),
        borderRadius: BorderRadius.zero,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: kMint),
        borderRadius: BorderRadius.zero,
      ),
      hintStyle: mono(color: kDim, fontSize: 13),
    ),
  );
}
