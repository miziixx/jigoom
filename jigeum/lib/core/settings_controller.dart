import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../providers.dart';
import 'theme.dart';

/// 앱 표시 설정 (테마·폰트 크기·굵기). DB settings 표에 영구 저장.
class AppSettings {
  const AppSettings({
    this.themeKey = kDefaultThemeKey,
    this.fontScale = 1.0,
    this.weightDelta = 0,
    this.systemFont = false,
    this.skyMode = 'both',
  });

  final String themeKey; // 내장 10종 중 하나 (기본 manila)
  final double fontScale; // 0.85 ~ 1.4
  final int weightDelta; // -1 ~ +2 (얇게 ~ 굵게)
  final bool systemFont; // true면 라벨·숫자도 기기 글꼴(모노 끄기)
  final String skyMode; // 'both' | 'zodiac' | 'saju' | 'none'

  /// 헤더에 별자리(점성술) 표시 여부.
  bool get showZodiac => skyMode == 'both' || skyMode == 'zodiac';

  /// 헤더에 만세력(년·월·일주) 표시 여부.
  bool get showSaju => skyMode == 'both' || skyMode == 'saju';

  AppSettings copyWith({
    String? themeKey,
    double? fontScale,
    int? weightDelta,
    bool? systemFont,
    String? skyMode,
  }) =>
      AppSettings(
        themeKey: themeKey ?? this.themeKey,
        fontScale: fontScale ?? this.fontScale,
        weightDelta: weightDelta ?? this.weightDelta,
        systemFont: systemFont ?? this.systemFont,
        skyMode: skyMode ?? this.skyMode,
      );
}

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this.db) : super(const AppSettings()) {
    _load();
  }

  final AppDatabase db;

  static const _kScale = 'font_scale';
  static const _kWeight = 'weight_delta';
  static const _kTheme = 'theme_key';
  static const _kSystemFont = 'system_font';
  static const _kSkyMode = 'sky_mode';

  Future<void> _load() async {
    final scale = await _get(_kScale);
    final weight = await _get(_kWeight);
    final theme = await _get(_kTheme);
    final sysFont = await _get(_kSystemFont);
    final sky = await _get(_kSkyMode);
    state = AppSettings(
      themeKey: theme ?? kDefaultThemeKey,
      fontScale: double.tryParse(scale ?? '') ?? 1.0,
      weightDelta: int.tryParse(weight ?? '') ?? 0,
      systemFont: sysFont == '1',
      skyMode: sky ?? 'both',
    );
  }

  Future<void> setSkyMode(String v) async {
    state = state.copyWith(skyMode: v);
    await _set(_kSkyMode, v);
  }

  Future<void> setThemeKey(String key) async {
    state = state.copyWith(themeKey: key);
    await _set(_kTheme, key);
  }

  Future<void> setSystemFont(bool v) async {
    state = state.copyWith(systemFont: v);
    await _set(_kSystemFont, v ? '1' : '0');
  }

  Future<void> setFontScale(double v) async {
    state = state.copyWith(fontScale: v);
    await _set(_kScale, '$v');
  }

  Future<void> setWeightDelta(int v) async {
    state = state.copyWith(weightDelta: v);
    await _set(_kWeight, '$v');
  }

  Future<String?> _get(String key) async {
    final row =
        await (db.select(db.settings)..where((s) => s.key.equals(key)))
            .getSingleOrNull();
    return row?.value;
  }

  Future<void> _set(String key, String value) async {
    await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value));
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(dbProvider));
});
