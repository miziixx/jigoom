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
    this.birth,
    this.birthHasTime = false,
    this.birthLongitude = 126.98, // 기본 서울
    this.birthLatitude = 37.57, // 기본 서울
    this.birthMale = true,
    this.birthPlace = '서울',
    this.birthCalendar = 'solar', // 입력 방식(표시용): 'solar' | 'lunar'
    this.birthLeap = false, // 음력 윤달 입력 여부(표시용)
    this.sajuLevel = 'general', // 사주 풀이 설명 레벨
    this.astroLevel = 'general', // 점성학 풀이 설명 레벨
    this.calSaju = true, // 캘린더에 사주(일진·오늘 기운) 표시
    this.calAstro = true, // 캘린더에 점성학(별자리) 표시
  });

  final String themeKey; // 내장 10종 중 하나 (기본 manila)
  final double fontScale; // 0.85 ~ 1.4
  final int weightDelta; // -1 ~ +2 (얇게 ~ 굵게)
  final bool systemFont; // true면 라벨·숫자도 기기 글꼴(모노 끄기)
  final String skyMode; // 'both' | 'zodiac' | 'saju' | 'none'
  final DateTime? birth; // 생년월일(+시각) — 항상 '양력' 시각으로 저장(civil).
  final bool birthHasTime; // 태어난 시각을 입력했는가(시주 포함 여부)
  final double birthLongitude; // 출생지 경도(동경) — 진태양시 보정용
  final double birthLatitude; // 출생지 위도(북위) — 상승궁(점성) 근사용
  final bool birthMale; // 성별(대운 방향 계산용). true=남
  final String birthPlace; // 출생지 이름(표시용)
  final String birthCalendar; // 입력 달력 표시용
  final bool birthLeap; // 음력 윤달 입력이었는지(표시용)
  final String sajuLevel; // 사주 풀이 레벨 키(explain.dart)
  final String astroLevel; // 점성학 풀이 레벨 키(explain.dart)
  final bool calSaju; // 캘린더 상세에 일진·오늘 기운 표시
  final bool calAstro; // 캘린더 상세에 별자리 표시

  /// 사주(오늘의 운세)를 계산할 수 있는가.
  bool get hasBirth => birth != null;

  /// 헤더에 별자리(점성술) 표시 여부.
  bool get showZodiac => skyMode == 'both' || skyMode == 'zodiac';

  /// 헤더에 만세력(년·월·일주) 표시 여부.
  bool get showSaju => skyMode == 'both' || skyMode == 'saju';

  static const _noArg = Object();

  AppSettings copyWith({
    String? themeKey,
    double? fontScale,
    int? weightDelta,
    bool? systemFont,
    String? skyMode,
    Object? birth = _noArg, // null 로 지울 수 있도록 sentinel 사용
    bool? birthHasTime,
    double? birthLongitude,
    double? birthLatitude,
    bool? birthMale,
    String? birthPlace,
    String? birthCalendar,
    bool? birthLeap,
    String? sajuLevel,
    String? astroLevel,
    bool? calSaju,
    bool? calAstro,
  }) =>
      AppSettings(
        themeKey: themeKey ?? this.themeKey,
        fontScale: fontScale ?? this.fontScale,
        weightDelta: weightDelta ?? this.weightDelta,
        systemFont: systemFont ?? this.systemFont,
        skyMode: skyMode ?? this.skyMode,
        birth: identical(birth, _noArg) ? this.birth : birth as DateTime?,
        birthHasTime: birthHasTime ?? this.birthHasTime,
        birthLongitude: birthLongitude ?? this.birthLongitude,
        birthLatitude: birthLatitude ?? this.birthLatitude,
        birthMale: birthMale ?? this.birthMale,
        birthPlace: birthPlace ?? this.birthPlace,
        birthCalendar: birthCalendar ?? this.birthCalendar,
        birthLeap: birthLeap ?? this.birthLeap,
        sajuLevel: sajuLevel ?? this.sajuLevel,
        astroLevel: astroLevel ?? this.astroLevel,
        calSaju: calSaju ?? this.calSaju,
        calAstro: calAstro ?? this.calAstro,
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
  static const _kBirth = 'birth_at'; // ISO8601 (local) — 항상 양력 시각
  static const _kBirthHasTime = 'birth_has_time';
  static const _kBirthLng = 'birth_lng';
  static const _kBirthLat = 'birth_lat';
  static const _kBirthMale = 'birth_male';
  static const _kBirthPlace = 'birth_place';
  static const _kBirthCal = 'birth_cal';
  static const _kBirthLeap = 'birth_leap';
  static const _kSajuLevel = 'saju_level';
  static const _kAstroLevel = 'astro_level';
  static const _kCalSaju = 'cal_saju';
  static const _kCalAstro = 'cal_astro';

  Future<void> _load() async {
    final scale = await _get(_kScale);
    final weight = await _get(_kWeight);
    final theme = await _get(_kTheme);
    final sysFont = await _get(_kSystemFont);
    final sky = await _get(_kSkyMode);
    final birthStr = await _get(_kBirth);
    final birthHasTime = await _get(_kBirthHasTime);
    final lng = await _get(_kBirthLng);
    final lat = await _get(_kBirthLat);
    final male = await _get(_kBirthMale);
    final place = await _get(_kBirthPlace);
    final cal = await _get(_kBirthCal);
    final leap = await _get(_kBirthLeap);
    final sajuLevel = await _get(_kSajuLevel);
    final astroLevel = await _get(_kAstroLevel);
    final calSaju = await _get(_kCalSaju);
    final calAstro = await _get(_kCalAstro);
    state = AppSettings(
      themeKey: theme ?? kDefaultThemeKey,
      fontScale: double.tryParse(scale ?? '') ?? 1.0,
      weightDelta: int.tryParse(weight ?? '') ?? 0,
      systemFont: sysFont == '1',
      skyMode: sky ?? 'both',
      birth: (birthStr == null || birthStr.isEmpty)
          ? null
          : DateTime.tryParse(birthStr),
      birthHasTime: birthHasTime == '1',
      birthLongitude: double.tryParse(lng ?? '') ?? 126.98,
      birthLatitude: double.tryParse(lat ?? '') ?? 37.57,
      birthMale: male == null ? true : male == '1',
      birthPlace: place ?? '서울',
      birthCalendar: cal ?? 'solar',
      birthLeap: leap == '1',
      sajuLevel: sajuLevel ?? 'general',
      astroLevel: astroLevel ?? 'general',
      calSaju: calSaju == null ? true : calSaju == '1',
      calAstro: calAstro == null ? true : calAstro == '1',
    );
  }

  /// 생년월일시(양력으로 변환된 civil 시각) 저장.
  Future<void> setBirth(
    DateTime birth, {
    required bool hasTime,
    double? longitude,
    double? latitude,
    bool? male,
    String? place,
    String? calendar,
    bool? leap,
  }) async {
    state = state.copyWith(
      birth: birth,
      birthHasTime: hasTime,
      birthLongitude: longitude,
      birthLatitude: latitude,
      birthMale: male,
      birthPlace: place,
      birthCalendar: calendar,
      birthLeap: leap,
    );
    await _set(_kBirth, birth.toIso8601String());
    await _set(_kBirthHasTime, hasTime ? '1' : '0');
    if (longitude != null) await _set(_kBirthLng, '$longitude');
    if (latitude != null) await _set(_kBirthLat, '$latitude');
    if (male != null) await _set(_kBirthMale, male ? '1' : '0');
    if (place != null) await _set(_kBirthPlace, place);
    if (calendar != null) await _set(_kBirthCal, calendar);
    if (leap != null) await _set(_kBirthLeap, leap ? '1' : '0');
  }

  Future<void> setSajuLevel(String key) async {
    state = state.copyWith(sajuLevel: key);
    await _set(_kSajuLevel, key);
  }

  Future<void> setCalSaju(bool v) async {
    state = state.copyWith(calSaju: v);
    await _set(_kCalSaju, v ? '1' : '0');
  }

  Future<void> setCalAstro(bool v) async {
    state = state.copyWith(calAstro: v);
    await _set(_kCalAstro, v ? '1' : '0');
  }

  Future<void> setAstroLevel(String key) async {
    state = state.copyWith(astroLevel: key);
    await _set(_kAstroLevel, key);
  }

  Future<void> setLongitude(double lng, String place) async {
    state = state.copyWith(birthLongitude: lng, birthPlace: place);
    await _set(_kBirthLng, '$lng');
    await _set(_kBirthPlace, place);
  }

  Future<void> setMale(bool v) async {
    state = state.copyWith(birthMale: v);
    await _set(_kBirthMale, v ? '1' : '0');
  }

  /// 생년월일시 지우기.
  Future<void> clearBirth() async {
    state = state.copyWith(birth: null, birthHasTime: false);
    await _set(_kBirth, '');
    await _set(_kBirthHasTime, '0');
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
