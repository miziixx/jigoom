import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../providers.dart';
import 'constants.dart';
import 'theme.dart';

/// 앱 표시 설정 (테마·폰트 크기·굵기). DB settings 표에 영구 저장.
class AppSettings {
  const AppSettings({
    this.themeKey = kDefaultThemeKey,
    this.fontScale = 1.0,
    this.weightDelta = 0,
    this.systemFont = true,
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
    this.fontKey = kDefaultFontKey, // 시스템 글꼴을 끈 경우 쓸 앱 내장 글꼴
    this.quietMode = false, // 방해 금지 — 브리핑·상주 알림 억제(하이퍼포커스 보호)
    this.variedNudges = true, // 알림 문구를 매번 조금씩 바꿔 무뎌짐 방지
    this.reduceMotion = false, // 모션·완료 팝업 최소화(센서리 예민 대응)
    this.autoSuggestNext = true, // 완료 직후 다음 할 일 한 개 제안
    this.widgetQuickAdd = true, // 위젯 탭 → 앱 빠른 담기 입력창 열기
    this.lockAgenda = true, // 잠금화면에 오늘 일정을 상주 알림으로 표시
    // 커스텀 팔레트(테마 키 'custom' 일 때 사용). 기본값 = 곰곰.
    this.customPaper = 0xFFEAE4D9, // 배경
    this.customInk = 0xFF231E18, // 글자
    this.customInkSoft = 0xFF897F70, // 보조 글자
    this.customLine = 0xFFDAD2C3, // 구분선
    this.customMark = 0xFFD6852A, // 포인트
  });

  final String themeKey; // 내장 10종 중 하나 (기본 manila)
  final double fontScale; // 0.85 ~ 1.4
  final int weightDelta; // -1 ~ +2 (얇게 ~ 굵게)
  final bool systemFont; // true면 폰 시스템 글꼴 사용(fontFamily 지정 안 함)
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
  final String fontKey; // 앱 내장 글꼴 키(kFonts)
  final bool quietMode; // 방해 금지(브리핑·상주 알림 억제)
  final bool variedNudges; // 알림 문구 변주
  final bool reduceMotion; // 모션·완료 팝업 최소화
  final bool autoSuggestNext; // 완료 직후 다음 할 일 한 개 제안
  final bool widgetQuickAdd; // 위젯에서 빠른 입력(앱 담기 입력창) 사용
  final bool lockAgenda; // 잠금화면 오늘 일정 상주 알림
  final int customPaper; // 커스텀 팔레트 — 배경(ARGB)
  final int customInk; // 커스텀 팔레트 — 글자(ARGB)
  final int customInkSoft; // 커스텀 팔레트 — 보조 글자(ARGB)
  final int customLine; // 커스텀 팔레트 — 구분선(ARGB)
  final int customMark; // 커스텀 팔레트 — 포인트(ARGB)

  /// 커스텀 팔레트 6토큰. paper2(눌림 배경)는 배경을 살짝 어둡게 자동 파생.
  AppTokens get customTokens => AppTokens(
        paper: Color(customPaper),
        paper2: Color.alphaBlend(const Color(0x0F000000), Color(customPaper)),
        ink: Color(customInk),
        inkSoft: Color(customInkSoft),
        line: Color(customLine),
        mark: Color(customMark),
      );

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
    String? fontKey,
    bool? quietMode,
    bool? variedNudges,
    bool? reduceMotion,
    bool? autoSuggestNext,
    bool? widgetQuickAdd,
    bool? lockAgenda,
    int? customPaper,
    int? customInk,
    int? customInkSoft,
    int? customLine,
    int? customMark,
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
        fontKey: fontKey ?? this.fontKey,
        quietMode: quietMode ?? this.quietMode,
        variedNudges: variedNudges ?? this.variedNudges,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        autoSuggestNext: autoSuggestNext ?? this.autoSuggestNext,
        widgetQuickAdd: widgetQuickAdd ?? this.widgetQuickAdd,
        lockAgenda: lockAgenda ?? this.lockAgenda,
        customPaper: customPaper ?? this.customPaper,
        customInk: customInk ?? this.customInk,
        customInkSoft: customInkSoft ?? this.customInkSoft,
        customLine: customLine ?? this.customLine,
        customMark: customMark ?? this.customMark,
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
  static const _kFontKey = 'font_key';
  static const _kQuietMode = 'quiet_mode';
  static const _kVariedNudges = 'varied_nudges';
  static const _kReduceMotion = 'reduce_motion';
  static const _kAutoSuggestNext = 'auto_suggest_next';
  static const _kWidgetQuickAdd = 'widget_quick_add';
  static const _kLockAgenda = 'lock_agenda';
  static const _kCPaper = 'custom_paper';
  static const _kCInk = 'custom_ink';
  static const _kCInkSoft = 'custom_ink_soft';
  static const _kCLine = 'custom_line';
  static const _kCMark = 'custom_mark';

  Future<void> _load() async {
    final scale = await _get(_kScale);
    final weight = await _get(_kWeight);
    var theme = await _get(_kTheme);
    // 곰곰 리디자인: 기본 테마를 '곰곰'(웜 팔레트)로 1회 이관. 아직 자기 테마를
    // 직접 고르지 않아 옛 기본값(manila/sage)에 머문 설치만 옮긴다. 다른 테마를
    // 고른 사용자는 그 선택을 유지하고, 이관 후 다시 고르면 그 선택이 유지된다.
    final gomgomMigrated = await _get('v4_gomgom_migrated');
    if (gomgomMigrated != '1') {
      if (theme == null || theme == 'manila' || theme == 'sage') {
        theme = 'gomgom';
        await _set(_kTheme, 'gomgom');
      }
      await _set('v4_gomgom_migrated', '1');
    }
    // 곰곰 리디자인: 폰 기본(시스템) 글꼴로 1회 이관 — 번들 명조/Pretendard 강제
    // 해제. 사용자가 설정에서 '내장 글꼴'을 다시 켜면 그 선택이 유지된다.
    final sysfontMigrated = await _get('v4_systemfont_migrated');
    if (sysfontMigrated != '1') {
      await _set(_kSystemFont, '1');
      await _set('v4_systemfont_migrated', '1');
    }
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
    final fontKey = await _get(_kFontKey);
    final quietMode = await _get(_kQuietMode);
    final variedNudges = await _get(_kVariedNudges);
    final reduceMotion = await _get(_kReduceMotion);
    final autoSuggestNext = await _get(_kAutoSuggestNext);
    final widgetQuickAdd = await _get(_kWidgetQuickAdd);
    final lockAgenda = await _get(_kLockAgenda);
    final cPaper = await _get(_kCPaper);
    final cInk = await _get(_kCInk);
    final cInkSoft = await _get(_kCInkSoft);
    final cLine = await _get(_kCLine);
    final cMark = await _get(_kCMark);
    // 비동기 로드 도중 컨트롤러가 dispose 되면 state 설정을 건너뛴다(use-after-dispose 방지).
    if (!mounted) return;
    const d = AppSettings();
    state = AppSettings(
      themeKey: theme ?? kDefaultThemeKey,
      fontScale: double.tryParse(scale ?? '') ?? 1.0,
      weightDelta: int.tryParse(weight ?? '') ?? 0,
      systemFont: sysFont == null ? true : sysFont == '1',
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
      fontKey: fontKey ?? kDefaultFontKey,
      quietMode: quietMode == '1',
      variedNudges: variedNudges == null ? true : variedNudges == '1',
      reduceMotion: reduceMotion == '1',
      autoSuggestNext:
          autoSuggestNext == null ? true : autoSuggestNext == '1',
      widgetQuickAdd: widgetQuickAdd == null ? true : widgetQuickAdd == '1',
      lockAgenda: lockAgenda == null ? true : lockAgenda == '1',
      customPaper: int.tryParse(cPaper ?? '') ?? d.customPaper,
      customInk: int.tryParse(cInk ?? '') ?? d.customInk,
      customInkSoft: int.tryParse(cInkSoft ?? '') ?? d.customInkSoft,
      customLine: int.tryParse(cLine ?? '') ?? d.customLine,
      customMark: int.tryParse(cMark ?? '') ?? d.customMark,
    );
  }

  /// 커스텀 팔레트의 한 역할 색을 바꾸고, 테마를 'custom' 으로 전환한다.
  Future<void> setCustomColor({
    int? paper,
    int? ink,
    int? inkSoft,
    int? line,
    int? mark,
  }) async {
    state = state.copyWith(
      themeKey: kCustomThemeKey,
      customPaper: paper,
      customInk: ink,
      customInkSoft: inkSoft,
      customLine: line,
      customMark: mark,
    );
    await _set(_kTheme, kCustomThemeKey);
    if (paper != null) await _set(_kCPaper, '$paper');
    if (ink != null) await _set(_kCInk, '$ink');
    if (inkSoft != null) await _set(_kCInkSoft, '$inkSoft');
    if (line != null) await _set(_kCLine, '$line');
    if (mark != null) await _set(_kCMark, '$mark');
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

  Future<void> setFontKey(String key) async {
    // 특정 글꼴을 고르면 '휴대폰 글꼴 사용'을 끄고 그 글꼴을 실제로 적용한다.
    state = state.copyWith(fontKey: key, systemFont: false);
    await _set(_kFontKey, key);
    await _set(_kSystemFont, '0');
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

  Future<void> setQuietMode(bool v) async {
    state = state.copyWith(quietMode: v);
    await _set(_kQuietMode, v ? '1' : '0');
  }

  Future<void> setVariedNudges(bool v) async {
    state = state.copyWith(variedNudges: v);
    await _set(_kVariedNudges, v ? '1' : '0');
  }

  Future<void> setReduceMotion(bool v) async {
    state = state.copyWith(reduceMotion: v);
    await _set(_kReduceMotion, v ? '1' : '0');
  }

  Future<void> setAutoSuggestNext(bool v) async {
    state = state.copyWith(autoSuggestNext: v);
    await _set(_kAutoSuggestNext, v ? '1' : '0');
  }

  Future<void> setWidgetQuickAdd(bool v) async {
    state = state.copyWith(widgetQuickAdd: v);
    await _set(_kWidgetQuickAdd, v ? '1' : '0');
  }

  Future<void> setLockAgenda(bool v) async {
    state = state.copyWith(lockAgenda: v);
    await _set(_kLockAgenda, v ? '1' : '0');
  }

  Future<String?> _get(String key) async {
    final row = await (db.select(db.settings)..where((s) => s.key.equals(key)))
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
