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
    kBg = const Color(0xFF000000);
    kSurface = const Color(0xFF050505);
    kText = const Color(0xFF00FF66);
    kDim = const Color(0xFF00A844);
    kBorder = const Color(0xFF00CC55);
    kMint = const Color(0xFF00FF66);
    kTeal = const Color(0xFF66FF99);
    kFontFamily = 'JetBrains Mono';
  }
  themeNotifier.value++;
  syncSystemUiOverlay();
}

void applyColors(Color bg, Color text) {
  kBg = bg;
  kText = text;
  kSurface = Color.lerp(bg, Colors.black, 0.05)!;
  kBorder = Color.lerp(bg, text, 0.35)!;
  kDim = Color.lerp(text, bg, 0.25)!;
  kMint = text;
  kTeal = Color.lerp(text, Colors.black, 0.15)!;
  themeNotifier.value++;
  syncSystemUiOverlay();
}

void applyLogroomFinalDefaults() {
  // HTML v2 palette: --bg #F1EDE3 / --txt #1C1A12 / --hi #5A4A2E / --hi2 #8A6E42
  applyColors(const Color(0xFFF1EDE3), const Color(0xFF1C1A12));
  kSurface = const Color(0xFFE2DDD1); // --sur
  kBorder = const Color(0xFFC0B8A4); // --brd
  kDim = const Color(0xFF7C7462); // --mu
  kMint = const Color(0xFF5A4A2E); // --hi  (accent/active/links)
  kTeal = const Color(0xFF8A6E42); // --hi2
  themeNotifier.value++;
  syncSystemUiOverlay();
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
