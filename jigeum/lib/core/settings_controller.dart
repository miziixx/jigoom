import 'package:drift/drift.dart';
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
  });

  final String themeKey; // 내장 10종 중 하나 (기본 manila)
  final double fontScale; // 0.85 ~ 1.4
  final int weightDelta; // -1 ~ +2 (얇게 ~ 굵게)

  AppSettings copyWith({String? themeKey, double? fontScale, int? weightDelta}) =>
      AppSettings(
        themeKey: themeKey ?? this.themeKey,
        fontScale: fontScale ?? this.fontScale,
        weightDelta: weightDelta ?? this.weightDelta,
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

  Future<void> _load() async {
    final scale = await _get(_kScale);
    final weight = await _get(_kWeight);
    final theme = await _get(_kTheme);
    state = AppSettings(
      themeKey: theme ?? kDefaultThemeKey,
      fontScale: double.tryParse(scale ?? '') ?? 1.0,
      weightDelta: int.tryParse(weight ?? '') ?? 0,
    );
  }

  Future<void> setThemeKey(String key) async {
    state = state.copyWith(themeKey: key);
    await _set(_kTheme, key);
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
