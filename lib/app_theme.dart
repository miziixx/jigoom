import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// All mutable — updated together by applyColors()
Color kBg      = const Color(0xFFEDF2ED);
Color kText    = const Color(0xFF556B2F);
Color kSurface = const Color(0xFFE0E8E0);
Color kBorder  = const Color(0xFFB0C4B0);
Color kDim     = const Color(0xFF7A8F5A);

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
double kFontSize   = 13.0;

final themeNotifier = ValueNotifier<int>(0);

void applyColors(Color bg, Color text) {
  kBg      = bg;
  kText    = text;
  kSurface = Color.lerp(bg, Colors.black, 0.05)!;
  kBorder  = Color.lerp(bg, text, 0.35)!;
  kDim     = Color.lerp(text, bg, 0.25)!;
  kMint    = text;
  kTeal    = Color.lerp(text, Colors.black, 0.15)!;
  themeNotifier.value++;
  syncSystemUiOverlay();
}

void syncSystemUiOverlay() {
  // Determine if background is dark so we can pick appropriate icon brightness
  final brightness = ThemeData.estimateBrightnessForColor(kBg);
  final iconBrightness = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: brightness,
    systemNavigationBarColor: kBg,
    systemNavigationBarIconBrightness: iconBrightness,
  ));
}

void applyFont(String family, double size) {
  kFontFamily = family;
  kFontSize   = size;
  themeNotifier.value++;
}

TextStyle mono({
  Color? color,
  double fontSize = 13,
  FontWeight fontWeight = FontWeight.normal,
  double? letterSpacing,
  double? height,
}) {
  final c  = color ?? kText;
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
