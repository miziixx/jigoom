import 'dart:math' as math;

import 'constants.dart';

/// 사주(四柱) 정밀 엔진 — 오프라인. 만세력 간지·지장간·오행 가중·십신·신강신약·
/// 용신·대운, 그리고 진태양시(경도·균시차·썸머타임) 보정.
///
/// almanac/constants 의 검증된 간지 계산(일주 anchor 2000-01-07, 년주 입춘,
/// 월주 오호둔·절기)을 재사용하고, 여기서 시주·보정·해석을 얹는다.
///
/// 정확도 주의: 사주는 유파·규칙마다 해석이 달라, 여기 결과(신강신약·용신·대운수)는
/// 대표적 규칙에 따른 근사다. 진태양시는 경도·균시차·한국 표준시 변천(1954–1961
/// 동경 127.5°, 1948–51·1987–88 서머타임)을 반영한다.

// ---------------------------------------------------------------- 천간·지지
const stemKor = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
const stemHanja = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
const branchKor = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];
const branchHanja = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
const branchAnimal = ['쥐', '소', '호랑이', '토끼', '용', '뱀', '말', '양', '원숭이', '닭', '개', '돼지'];

const _branchHours = [
  '23:30–01:30', '01:30–03:30', '03:30–05:30', '05:30–07:30', '07:30–09:30',
  '09:30–11:30', '11:30–13:30', '13:30–15:30', '15:30–17:30', '17:30–19:30',
  '19:30–21:30', '21:30–23:30',
];

// ---------------------------------------------------------------- 오행(五行)
const wuxingKor = ['목', '화', '토', '금', '수'];
const wuxingHanja = ['木', '火', '土', '金', '水'];
const wuxingTrait = ['성장·추진', '열정·표현', '안정·중용', '결단·규율', '지혜·유연'];

const _branchWuxing = [4, 2, 0, 0, 2, 1, 1, 2, 3, 3, 2, 4];

int stemWuxing(int s) => s ~/ 2;
int branchWuxing(int b) => _branchWuxing[b];
bool stemYang(int s) => s % 2 == 0;
bool branchYang(int b) => b % 2 == 0;

// 지장간(支藏干) — 각 지지 안에 숨은 천간. 마지막 원소가 정기(正氣·본기).
const _hiddenStems = <List<int>>[
  [8, 9], // 子: 壬 癸
  [9, 7, 5], // 丑: 癸 辛 己
  [4, 2, 0], // 寅: 戊 丙 甲
  [0, 1], // 卯: 甲 乙
  [1, 9, 4], // 辰: 乙 癸 戊
  [4, 6, 2], // 巳: 戊 庚 丙
  [2, 5, 3], // 午: 丙 己 丁
  [3, 1, 5], // 未: 丁 乙 己
  [4, 8, 6], // 申: 戊 壬 庚
  [6, 7], // 酉: 庚 辛
  [7, 3, 4], // 戌: 辛 丁 戊
  [4, 0, 8], // 亥: 戊 甲 壬
];

/// 지지의 지장간 천간 index 목록(정기가 마지막).
List<int> hiddenStems(int branch) => _hiddenStems[branch];

/// 지지 정기(본기) 천간.
int mainHiddenStem(int branch) => _hiddenStems[branch].last;

// ---------------------------------------------------------------- 십신(十神)
enum TenGodGroup { bigyeop, siksang, jaeseong, gwanseong, inseong }

const tenGodGroupKor = ['비겁', '식상', '재성', '관성', '인성'];
const tenGodGroupDesc = [
  '자아·경쟁·동료',
  '표현·재능·활동',
  '재물·현실성과',
  '직장·규율·명예',
  '학습·수용·안정',
];

TenGodGroup tenGodGroupOf(int dayStem, int otherWuxing) {
  final me = stemWuxing(dayStem);
  if (me == otherWuxing) return TenGodGroup.bigyeop;
  if ((me + 1) % 5 == otherWuxing) return TenGodGroup.siksang;
  if ((me + 2) % 5 == otherWuxing) return TenGodGroup.jaeseong;
  if ((otherWuxing + 2) % 5 == me) return TenGodGroup.gwanseong;
  return TenGodGroup.inseong;
}

/// 일간 기준 상대 천간의 정확한 십신 이름(음양 구분).
String tenGodName(int dayStem, int otherStem) {
  final group = tenGodGroupOf(dayStem, stemWuxing(otherStem));
  final same = stemYang(dayStem) == stemYang(otherStem);
  switch (group) {
    case TenGodGroup.bigyeop:
      return same ? '비견' : '겁재';
    case TenGodGroup.siksang:
      return same ? '식신' : '상관';
    case TenGodGroup.jaeseong:
      return same ? '편재' : '정재';
    case TenGodGroup.gwanseong:
      return same ? '편관' : '정관';
    case TenGodGroup.inseong:
      return same ? '편인' : '정인';
  }
}

// ---------------------------------------------------------------- 지지 합·충
const _yukhap = [1, 0, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2];
int chungOf(int b) => (b + 6) % 12;
bool isHap(int a, int b) => _yukhap[a] == b;
bool isChung(int a, int b) => chungOf(a) == b;

// ---------------------------------------------------------------- 진태양시
// 출생지 좌표(경도·위도)는 core/regions.dart 의 지역 목록에서 얻는다.

/// 진태양시 보정 결과.
class TrueTime {
  const TrueTime(this.corrected, this.lonCorrMin, this.eotMin, this.dst,
      this.meridian);
  final DateTime corrected; // 보정된 시각
  final int lonCorrMin; // 경도차 보정(분)
  final int eotMin; // 균시차 보정(분)
  final bool dst; // 서머타임 적용 여부
  final double meridian; // 그 시기의 표준자오선(도)
}

/// 그 시기 한국의 (표준자오선, 서머타임 분).
(double, int) _koreaEra(DateTime t) {
  final ymd = t.year * 10000 + t.month * 100 + t.day;
  bool inRange(int a, int b) => ymd >= a && ymd <= b;
  const dst = [
    [19480601, 19480912],
    [19490403, 19490910],
    [19500401, 19500909],
    [19510506, 19510908],
    [19870510, 19871010],
    [19880508, 19881008],
  ];
  for (final w in dst) {
    if (inRange(w[0], w[1])) return (135.0, 60);
  }
  // 1954-03-21 ~ 1961-08-09: 동경 127.5° 표준시.
  if (inRange(19540321, 19610809)) return (127.5, 0);
  return (135.0, 0);
}

/// 균시차(분) — 저정밀 근사.
double equationOfTime(DateTime d) {
  final n = _dayOfYear(d);
  final b = 2 * math.pi * (n - 81) / 364.0;
  return 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);
}

int _dayOfYear(DateTime d) =>
    d.difference(DateTime(d.year, 1, 1)).inDays + 1;

/// 표준시 시계값(civil) → 진태양시. 경도·균시차·서머타임 반영.
TrueTime trueSolarTime(DateTime civil, double lonEast) {
  final (meridian, dstMin) = _koreaEra(civil);
  final lonCorr = ((lonEast - meridian) * 4).round();
  final eot = equationOfTime(civil).round();
  final corrected =
      civil.add(Duration(minutes: lonCorr + eot - dstMin));
  return TrueTime(corrected, lonCorr, eot, dstMin > 0, meridian);
}

// ---------------------------------------------------------------- 기둥·차트
class Pillar {
  const Pillar(this.stem, this.branch);
  final int stem;
  final int branch;

  String get hanja => '${stemHanja[stem]}${branchHanja[branch]}';
  String get kor => '${stemKor[stem]}${branchKor[branch]}';
  int get stemWx => stemWuxing(stem);
  int get branchWx => branchWuxing(branch);
}

/// 대운 한 구간(10년).
class Daeun {
  const Daeun(this.pillar, this.startAge);
  final Pillar pillar;
  final int startAge; // 이 대운이 시작되는 만 나이
  int get endAge => startAge + 9;
}

/// 개인 사주 원국 + 정밀 분석.
class SajuChart {
  SajuChart({
    required this.birth,
    required this.effective,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.hasHour,
    required this.male,
    required this.longitude,
    required this.trueTime,
    required this.forward,
    required this.daeunStartAge,
    required this.daeun,
  });

  final DateTime birth; // 입력된 표준시(civil)
  final DateTime effective; // 보정 적용된 시각(간지 판정 기준)
  final Pillar year;
  final Pillar month;
  final Pillar day;
  final Pillar? hour;
  final bool hasHour;
  final bool male;
  final double longitude;
  final TrueTime? trueTime; // 시 모름이면 null
  final bool forward; // 대운 순행 여부
  final int daeunStartAge; // 대운수(첫 대운 시작 나이)
  final List<Daeun> daeun;

  int get dayStem => day.stem;

  List<Pillar> get pillars =>
      [year, month, day, if (hour != null) hour!];

  List<int> get branches => pillars.map((p) => p.branch).toList();

  /// 단순 오행 개수(글자 수 기준).
  Map<int, int> get wuxingCount {
    final m = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0};
    for (final p in pillars) {
      m[p.stemWx] = m[p.stemWx]! + 1;
      m[p.branchWx] = m[p.branchWx]! + 1;
    }
    return m;
  }

  /// 가중 오행 점수(천간 1.0, 지장간 정기 1.0·그외 0.35, 월령 본기 +1.0).
  Map<int, double> get wuxingScore {
    final m = {0: 0.0, 1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};
    for (final p in pillars) {
      m[stemWuxing(p.stem)] = m[stemWuxing(p.stem)]! + 1.0;
      final hs = hiddenStems(p.branch);
      for (var i = 0; i < hs.length; i++) {
        final w = i == hs.length - 1 ? 1.0 : 0.35;
        final wx = stemWuxing(hs[i]);
        m[wx] = m[wx]! + w;
      }
    }
    final monthMain = stemWuxing(mainHiddenStem(month.branch));
    m[monthMain] = m[monthMain]! + 1.0; // 월령 가중
    return m;
  }

  double get _totalScore =>
      wuxingScore.values.fold(0.0, (a, b) => a + b);

  int get dominantWuxing {
    final c = wuxingScore;
    var best = 0;
    for (var i = 1; i < 5; i++) {
      if (c[i]! > c[best]!) best = i;
    }
    return best;
  }

  int get weakestWuxing {
    final c = wuxingScore;
    var worst = 0;
    for (var i = 1; i < 5; i++) {
      if (c[i]! < c[worst]!) worst = i;
    }
    return worst;
  }

  /// 일간을 돕는 세력 비율(비겁+인성).
  double get supportRatio {
    final me = stemWuxing(dayStem);
    final resource = (me + 4) % 5;
    final c = wuxingScore;
    final total = _totalScore;
    if (total == 0) return 0.5;
    return (c[me]! + c[resource]!) / total;
  }

  /// 월령을 얻었는가(득령) — 월지 본기가 일간과 같거나 일간을 생함.
  bool get hasMonthCommand {
    final me = stemWuxing(dayStem);
    final monthWx = stemWuxing(mainHiddenStem(month.branch));
    return monthWx == me || (monthWx + 1) % 5 == me; // 같음 또는 인성
  }

  bool get isStrong =>
      supportRatio >= 0.42 || (hasMonthCommand && supportRatio >= 0.36);

  /// 신강/신약 강도(0~100, 대략).
  int get strengthPct {
    final v = (supportRatio * 100).round();
    return v < 0 ? 0 : (v > 100 ? 100 : v);
  }

  /// 십신 그룹 분포(일간 제외 천간 + 모든 지장간).
  Map<TenGodGroup, int> get tenGodDistribution {
    final m = {for (final g in TenGodGroup.values) g: 0};
    void add(int stem) {
      final g = tenGodGroupOf(dayStem, stemWuxing(stem));
      m[g] = m[g]! + 1;
    }
    for (final p in pillars) {
      if (!identical(p, day)) add(p.stem); // 일간 자신은 제외
      for (final h in hiddenStems(p.branch)) {
        add(h);
      }
    }
    return m;
  }

  /// 억부용신(참고) — 오행 index. 신강이면 설기·극(식상/재/관), 신약이면 인·비.
  int get yongsin {
    final me = stemWuxing(dayStem);
    if (isStrong) {
      // 관(me+3)%5, 재(me+2)%5, 식상(me+1)%5 중 사주에 가장 강한 흐름을 이끌 것.
      final cand = [(me + 3) % 5, (me + 2) % 5, (me + 1) % 5];
      final c = wuxingScore;
      cand.sort((a, b) => c[b]!.compareTo(c[a]!));
      return cand.first;
    } else {
      // 인((me+4)%5) 우선, 부족하면 비(me).
      final resource = (me + 4) % 5;
      final c = wuxingScore;
      return c[resource]! <= c[me]! ? resource : me;
    }
  }

  String get yongsinReason => isStrong
      ? '신강 — 넘치는 기운을 덜어낼 ${wuxingKor[yongsin]}(${wuxingHanja[yongsin]})이 이로움'
      : '신약 — 일간을 도울 ${wuxingKor[yongsin]}(${wuxingHanja[yongsin]})이 이로움';

  /// 현재 만 나이 기준, 지금 지나는 대운.
  Daeun? currentDaeun(DateTime now) {
    final age = _ageAt(now);
    Daeun? cur;
    for (final d in daeun) {
      if (age >= d.startAge) cur = d;
    }
    return cur;
  }

  int _ageAt(DateTime now) {
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }
}

/// 표준시(civil) 생년월일시 → 사주 원국(정밀). [male]·[longitude]는 대운·시주 보정용.
SajuChart computeSaju(
  DateTime civilBirth, {
  required bool hasHour,
  double longitude = 135.0,
  bool male = true,
}) {
  // 시 모름이면 진태양시 보정은 의미 없음(날짜 판정만) → civil 그대로.
  final tt = hasHour ? trueSolarTime(civilBirth, longitude) : null;
  final eff = tt?.corrected ?? civilBirth;

  final yi = yearGanziIndex(eff);
  final year = Pillar(yi % 10, yi % 12);
  final month = Pillar(monthStemIndex(eff), monthBranchIndex(eff));
  final di = dayGanziIndex(eff);
  final day = Pillar(di % 10, di % 12);
  Pillar? hour;
  if (hasHour) {
    final hb = hourBranchIndex(eff.hour);
    hour = Pillar(hourStemIndex(day.stem, hb), hb);
  }

  // 대운 방향: 양남음녀 순행, 음남양녀 역행.
  final yearYang = stemYang(year.stem);
  final forward = (yearYang && male) || (!yearYang && !male);

  // 대운수: 절(節) 경계까지의 일수 / 3.
  final startDays = _daeunStartDays(eff, forward);
  final rawAge = (startDays / 3).round();
  final startAge = rawAge < 1 ? 1 : (rawAge > 10 ? 10 : rawAge);

  final mIdx = ganziIndexFromStemBranch(month.stem, month.branch);
  final daeun = <Daeun>[];
  for (var i = 0; i < 8; i++) {
    final step = forward ? (i + 1) : -(i + 1);
    final idx = ((mIdx + step) % 60 + 60) % 60;
    daeun.add(Daeun(Pillar(idx % 10, idx % 12), startAge + i * 10));
  }

  return SajuChart(
    birth: civilBirth,
    effective: eff,
    year: year,
    month: month,
    day: day,
    hour: hour,
    hasHour: hasHour,
    male: male,
    longitude: longitude,
    trueTime: tt,
    forward: forward,
    daeunStartAge: startAge,
    daeun: daeun,
  );
}

/// 시지(時支) index — 자시 23:30~01:30 = 0 (진태양시 기준 2시간 구간).
int hourBranchIndex(int hour24) => ((hour24 + 1) ~/ 2) % 12;

/// 시간(時干) index — 오자시둔(五鼠遁).
int hourStemIndex(int dayStem, int hourBranch) =>
    ((dayStem % 5) * 2 + hourBranch) % 10;

String hourRange(int branch) => _branchHours[branch];

/// 천간·지지 index → 60갑자 index(0~59).
int ganziIndexFromStemBranch(int stem, int branch) {
  for (var i = 0; i < 60; i++) {
    if (i % 10 == stem && i % 12 == branch) return i;
  }
  return 0;
}

/// 대운 시작까지의 일수 — 다음/이전 절(節, 월지 변화)까지.
int _daeunStartDays(DateTime eff, bool forward) {
  final mb = monthBranchIndex(eff);
  var d = DateTime(eff.year, eff.month, eff.day);
  var cnt = 0;
  while (monthBranchIndex(d) == mb && cnt < 40) {
    d = forward
        ? d.add(const Duration(days: 1))
        : d.subtract(const Duration(days: 1));
    cnt++;
  }
  return cnt == 0 ? 1 : cnt;
}
