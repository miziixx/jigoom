import 'almanac.dart';
import 'astrology.dart';
import 'constants.dart';
import 'saju.dart';

/// 오늘의 운세 엔진 — 오프라인 규칙 기반.
///
/// 개인 사주 원국(SajuChart)과 오늘의 간지·절기를 십신(十神)·오행 상생상극·지지 합충
/// 규칙으로 조합해 카테고리별 점수(0~100)를 만든다. 결정적 함수이므로 같은 사주·같은
/// 날짜엔 항상 같은 결과가 나온다(재현성). 점수의 소폭 변동은 날짜·사주 해시 기반
/// 지터로만 준다 — 무작위가 아니다.
///
/// 텍스트(풀이·요약·조언)는 이 파일이 아니라 fortune_text.dart 의 렌더러가 만든다.
/// 여기서는 점수와 **구조화된 신호(FortuneSignals)** 만 계산하고, 렌더러가 설명 레벨
/// (일반인·왕초보·초보·중급·고급)에 맞춰 풀이를 붙인다.

/// 한 카테고리의 운세 결과(점수 + 신호). 풀이는 fortune_text.describe()가 만든다.
class FortuneCategory {
  const FortuneCategory({
    required this.key,
    required this.title,
    required this.glyph,
    required this.score,
    required this.sig,
  });

  final String key;
  final String title;
  final String glyph;
  final int score; // 0~100
  final FortuneSignals sig;

  String get grade => gradeLabel(score);
}

/// 모든 카테고리가 공유하는 오늘×사주 관계 신호 — 렌더러가 이걸 읽어 풀이를 만든다.
class FortuneSignals {
  const FortuneSignals({
    required this.group,
    required this.strong,
    required this.strengthPct,
    required this.hap,
    required this.chung,
    required this.helpsWeak,
    required this.overloads,
    required this.supports,
    required this.spouseHap,
    required this.spouseChung,
    required this.hasHour,
    required this.meWx,
    required this.todayStemWx,
    required this.todayBranchWx,
    required this.weakestWx,
    required this.dominantWx,
    required this.yongsinWx,
    required this.dayStem,
    required this.dayBranch,
    required this.todayStem,
    required this.todayBranch,
    required this.todayHanja,
    required this.todayKor,
    required this.todayTenGod,
    required this.todayIsNoble,
    required this.todayIsYeokma,
    required this.earthFlow,
    required this.todaySunSign,
    required this.todayMoonSign,
    required this.solarTerm,
  });

  final TenGodGroup group; // 오늘 기운이 나에게 무슨 십신인가
  final bool strong; // 신강 여부
  final int strengthPct;
  final int hap, chung; // 내 원국과 오늘 지지의 합·충 개수
  final bool helpsWeak, overloads, supports, spouseHap, spouseChung, hasHour;
  final int meWx, todayStemWx, todayBranchWx;
  final int weakestWx, dominantWx, yongsinWx;
  final int dayStem, dayBranch, todayStem, todayBranch;
  final String todayHanja, todayKor, todayTenGod;
  final bool todayIsNoble; // 오늘 지지가 내 천을귀인
  final bool todayIsYeokma; // 오늘 지지가 역마(寅申巳亥)
  final String earthFlow; // 상생(相生)/상극(相剋)/나란함
  final String todaySunSign, todayMoonSign; // 오늘 하늘(점성)
  final String? solarTerm;
}

/// 하루치 운세 전체.
class DailyFortune {
  const DailyFortune({
    required this.date,
    required this.chart,
    required this.todayPillar,
    required this.solarTerm,
    required this.overall,
    required this.categories,
  });

  final DateTime date;
  final SajuChart chart;
  final Pillar todayPillar;
  final String? solarTerm;
  final int overall;
  final List<FortuneCategory> categories;

  String get overallGrade => gradeLabel(overall);
  TenGodGroup get todayGroup =>
      tenGodGroupOf(chart.dayStem, stemWuxing(todayPillar.stem));
  String get todayTenGod => tenGodName(chart.dayStem, todayPillar.stem);
}

/// 점수 → 등급 라벨.
String gradeLabel(int s) => s >= 85
    ? '대길'
    : s >= 70
        ? '길'
        : s >= 55
            ? '순조'
            : s >= 40
                ? '보통'
                : '주의';

// 천을귀인(天乙貴人) 지지 — 일간별. 역마(驛馬) 지지 = 寅申巳亥.
const _nobleBranches = <List<int>>[
  [1, 7], // 甲: 丑未
  [0, 8], // 乙: 子申
  [11, 9], // 丙: 亥酉
  [11, 9], // 丁: 亥酉
  [1, 7], // 戊: 丑未
  [0, 8], // 己: 子申
  [1, 7], // 庚: 丑未
  [2, 6], // 辛: 寅午
  [5, 3], // 壬: 巳卯
  [5, 3], // 癸: 巳卯
];
const _yeokmaBranches = [2, 8, 5, 11]; // 寅申巳亥

// ------------------------------------------------------------------ 계산
DailyFortune computeDailyFortune(SajuChart chart, DateTime today) {
  final d = dateOnly(today);
  final ti = dayGanziIndex(d);
  final todayPillar = Pillar(ti % 10, ti % 12);
  final term = solarTermName(d);

  final ctx = _Ctx(chart, d, todayPillar);
  final sig = ctx.build(term);

  final cats = <FortuneCategory>[
    _career(ctx, sig),
    _wealth(ctx, sig),
    _relationship(ctx, sig),
    _love(ctx, sig),
    _documents(ctx, sig),
    _helpers(ctx, sig),
    _study(ctx, sig),
    _travel(ctx, sig),
    _disputes(ctx, sig),
    _body(ctx, sig),
    _mind(ctx, sig),
    _lucky(ctx, sig),
    _earth(ctx, sig),
  ];

  // 총운 = 개인 카테고리(지구에너지·행운요소 제외)의 평균 + 균형 보정.
  final personal =
      cats.where((c) => c.key != 'earth' && c.key != 'lucky').toList();
  final avg =
      personal.map((c) => c.score).reduce((a, b) => a + b) / personal.length;
  final overall = _clamp(avg.round() + ctx.balanceBonus);

  return DailyFortune(
    date: d,
    chart: chart,
    todayPillar: todayPillar,
    solarTerm: term,
    overall: overall,
    categories: [
      FortuneCategory(
          key: 'overall', title: '오늘의 총운', glyph: '◎', score: overall, sig: sig),
      ...cats,
    ],
  );
}

/// 계산 컨텍스트 — 모든 카테고리가 공유하는 오늘×사주 관계값.
class _Ctx {
  _Ctx(this.chart, this.date, this.today) {
    final me = stemWuxing(chart.dayStem);
    todayStemWx = stemWuxing(today.stem);
    todayBranchWx = branchWuxing(today.branch);
    group = tenGodGroupOf(chart.dayStem, todayStemWx);
    strong = chart.isStrong;

    var h = 0, c = 0;
    for (final b in chart.branches) {
      if (isHap(b, today.branch)) h++;
      if (isChung(b, today.branch)) c++;
    }
    hap = h;
    chung = c;

    final weak = chart.weakestWuxing;
    final dom = chart.dominantWuxing;
    helpsWeak = todayStemWx == weak || todayBranchWx == weak;
    overloads = todayStemWx == dom && chart.wuxingCount[dom]! >= 4;

    supports = group == TenGodGroup.bigyeop || group == TenGodGroup.inseong;
    spouseHap = isHap(chart.day.branch, today.branch);
    spouseChung = isChung(chart.day.branch, today.branch);
    meWx = me;
  }

  final SajuChart chart;
  final DateTime date;
  final Pillar today;
  late final int meWx, todayStemWx, todayBranchWx, hap, chung;
  late final TenGodGroup group;
  late final bool strong, helpsWeak, overloads, supports, spouseHap, spouseChung;

  bool get todayIsNoble => _nobleBranches[chart.dayStem].contains(today.branch);
  bool get todayIsYeokma => _yeokmaBranches.contains(today.branch);

  int get favor {
    switch (group) {
      case TenGodGroup.bigyeop:
        return strong ? -6 : 10;
      case TenGodGroup.inseong:
        return strong ? -4 : 9;
      case TenGodGroup.siksang:
        return strong ? 9 : -5;
      case TenGodGroup.jaeseong:
        return strong ? 11 : -3;
      case TenGodGroup.gwanseong:
        return strong ? 7 : -9;
    }
  }

  int get balanceBonus => (helpsWeak ? 4 : 0) - (overloads ? 4 : 0);

  int jitter(String key) {
    final base = date.year * 10000 + date.month * 100 + date.day;
    final salt = chart.dayStem * 131 + chart.day.branch * 17 + key.hashCode;
    return ((base ^ salt).abs() % 9) - 4;
  }

  /// 오늘 천간·지지 오행 상생/상극 결.
  String get earthFlow => (stemWuxing(today.stem) + 1) % 5 == todayBranchWx
      ? '상생(相生)'
      : (stemWuxing(today.stem) + 2) % 5 == todayBranchWx
          ? '상극(相剋)'
          : '나란함';

  FortuneSignals build(String? term) {
    final sky = computeTodaySky(date);
    return FortuneSignals(
      group: group,
      strong: strong,
      strengthPct: chart.strengthPct,
      hap: hap,
      chung: chung,
      helpsWeak: helpsWeak,
      overloads: overloads,
      supports: supports,
      spouseHap: spouseHap,
      spouseChung: spouseChung,
      hasHour: chart.hasHour,
      meWx: meWx,
      todayStemWx: todayStemWx,
      todayBranchWx: todayBranchWx,
      weakestWx: chart.weakestWuxing,
      dominantWx: chart.dominantWuxing,
      yongsinWx: chart.yongsin,
      dayStem: chart.dayStem,
      dayBranch: chart.day.branch,
      todayStem: today.stem,
      todayBranch: today.branch,
      todayHanja: today.hanja,
      todayKor: today.kor,
      todayTenGod: tenGodName(chart.dayStem, today.stem),
      todayIsNoble: todayIsNoble,
      todayIsYeokma: todayIsYeokma,
      earthFlow: earthFlow,
      todaySunSign: sky.sunSign.name,
      todayMoonSign: sky.moonSign.name,
      solarTerm: term,
    );
  }
}

int _clamp(int v) => v < 5 ? 5 : (v > 98 ? 98 : v);

FortuneCategory _cat(String key, String title, String glyph, int score,
        FortuneSignals sig) =>
    FortuneCategory(
        key: key, title: title, glyph: glyph, score: _clamp(score), sig: sig);

// ------------------------------------------------------------------ 카테고리 점수

FortuneCategory _career(_Ctx x, FortuneSignals s) {
  var v = 55 + (x.favor * 6 ~/ 10);
  if (x.group == TenGodGroup.gwanseong) v += x.strong ? 16 : -6;
  if (x.group == TenGodGroup.inseong) v += 5;
  v += x.hap * 4 - x.chung * 7 + x.jitter('career');
  return _cat('career', '직장·일', '⚑', v, s);
}

FortuneCategory _wealth(_Ctx x, FortuneSignals s) {
  var v = 55 + (x.favor * 5 ~/ 10);
  if (x.group == TenGodGroup.jaeseong) v += x.strong ? 15 : -2;
  if (x.group == TenGodGroup.siksang) v += 8;
  if (x.group == TenGodGroup.bigyeop) v += x.strong ? -4 : -10;
  v += x.hap * 3 - x.chung * 5 + x.jitter('wealth');
  return _cat('wealth', '재물', '❖', v, s);
}

FortuneCategory _relationship(_Ctx x, FortuneSignals s) {
  var v = 55;
  if (x.group == TenGodGroup.bigyeop) v += 12;
  if (x.group == TenGodGroup.siksang) v += 8;
  if (x.group == TenGodGroup.gwanseong) v += x.strong ? 4 : -6;
  v += x.hap * 6 - x.chung * 7 + x.jitter('relationship');
  return _cat('relationship', '인간관계', '⚭', v, s);
}

FortuneCategory _love(_Ctx x, FortuneSignals s) {
  var v = 55;
  if (x.spouseHap) v += 16;
  if (x.spouseChung) v += -12;
  if (x.group == TenGodGroup.jaeseong || x.group == TenGodGroup.gwanseong) {
    v += 8;
  }
  if (x.group == TenGodGroup.siksang) v += 5;
  v += x.jitter('love');
  return _cat('love', '애정·궁합', '♡', v, s);
}

FortuneCategory _documents(_Ctx x, FortuneSignals s) {
  var v = 55;
  if (x.group == TenGodGroup.inseong) v += 14; // 인성=문서·자격
  if (x.group == TenGodGroup.gwanseong) v += 6; // 정관=계약·공적문서
  if (x.group == TenGodGroup.siksang) v += x.strong ? 2 : -4;
  v += x.hap * 3 - x.chung * 5 + x.jitter('documents');
  return _cat('documents', '문서·계약', '✉', v, s);
}

FortuneCategory _helpers(_Ctx x, FortuneSignals s) {
  var v = 54;
  if (x.group == TenGodGroup.inseong) v += 10; // 인성=귀인·도움
  if (x.todayIsNoble) v += 12; // 천을귀인
  v += x.hap * 5 - x.chung * 3 + x.jitter('helpers');
  return _cat('helpers', '귀인·도움', '☆', v, s);
}

FortuneCategory _study(_Ctx x, FortuneSignals s) {
  var v = 55;
  if (x.group == TenGodGroup.inseong) v += 14;
  if (x.group == TenGodGroup.siksang) v += 6;
  if (x.helpsWeak) v += 5;
  v += x.hap * 2 - x.chung * 4 + x.jitter('study');
  return _cat('study', '학습·시험', '✎', v, s);
}

FortuneCategory _travel(_Ctx x, FortuneSignals s) {
  var v = 55;
  if (x.todayIsYeokma) v += 10; // 역마=이동
  if (x.chung > 0) v += 6; // 충=움직임(단, 총운엔 마이너스)
  if (x.group == TenGodGroup.jaeseong) v += 5; // 재=바깥활동
  if (x.group == TenGodGroup.siksang) v += 4;
  v += x.hap * 2 + x.jitter('travel');
  return _cat('travel', '이동·여행', '➤', v, s);
}

FortuneCategory _disputes(_Ctx x, FortuneSignals s) {
  // 높을수록 평온, 낮을수록 구설·시비 주의.
  var v = 64;
  if (x.chung > 0) v -= x.chung * 9; // 충=마찰
  if (x.group == TenGodGroup.siksang && !x.strong) v -= 8; // 상관=구설
  if (x.group == TenGodGroup.gwanseong && !x.strong) v -= 7; // 관살=압박·시비
  if (x.hap > 0) v += x.hap * 4; // 합=화해
  v += x.jitter('disputes');
  return _cat('disputes', '구설·시비', '‼', v, s);
}

FortuneCategory _body(_Ctx x, FortuneSignals s) {
  var v = 58;
  if (x.group == TenGodGroup.gwanseong && !x.strong) v -= 12;
  if (x.group == TenGodGroup.siksang && x.strong) v += 8;
  if (x.supports) v += 6;
  if (x.helpsWeak) v += 5;
  v += -x.chung * 8 + x.hap * 2 + x.jitter('body');
  return _cat('body', '건강·몸', '✚', v, s);
}

FortuneCategory _mind(_Ctx x, FortuneSignals s) {
  var v = 56;
  if (x.group == TenGodGroup.inseong) v += 12;
  if (x.group == TenGodGroup.siksang) v += x.strong ? 8 : 3;
  if (x.group == TenGodGroup.gwanseong && !x.strong) v -= 9;
  if (x.group == TenGodGroup.bigyeop) v += 4;
  v += x.hap * 3 - x.chung * 6 + x.jitter('mind');
  return _cat('mind', '마음·정신', '❋', v, s);
}

FortuneCategory _lucky(_Ctx x, FortuneSignals s) {
  var v = 60;
  if (x.todayBranchWx == x.chart.yongsin || x.todayStemWx == x.chart.yongsin) {
    v += 14; // 오늘 기운이 용신
  }
  if (x.helpsWeak) v += 6;
  v += x.jitter('lucky');
  return _cat('lucky', '행운 요소', '✧', v, s);
}

FortuneCategory _earth(_Ctx x, FortuneSignals s) {
  final flow = x.earthFlow;
  var v = flow == '상생(相生)'
      ? 74
      : flow == '상극(相剋)'
          ? 48
          : 62;
  v = v + x.jitter('earth');
  return _cat('earth', '지구의 에너지', '☯', v, s);
}
