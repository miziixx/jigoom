import 'constants.dart';

/// 사주(四柱) 계산 엔진 — 오프라인. 만세력 간지·오행(五行)·십신(十神).
///
/// almanac/constants 의 검증된 간지 계산(일주 anchor 2000-01-07, 년주 입춘,
/// 월주 오호둔)을 재사용하고, 여기서 시주(時柱)·오행·십신 해석을 얹는다.
///
/// 정확도: 절기·간지는 만세력과 대개 일치(자정 근처 경계일 ±1). 시주는 진태양시
/// 보정 없이 표준시(KST) 기준 2시간 지지로 근사한다. '오늘의 운세' 용도엔 충분.

// ---------------------------------------------------------------- 천간·지지
const stemKor = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
const stemHanja = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
const branchKor = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];
const branchHanja = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
const branchAnimal = ['쥐', '소', '호랑이', '토끼', '용', '뱀', '말', '양', '원숭이', '닭', '개', '돼지'];

// 시지(時支) 한글 라벨 — 예: "子시 (23–01)".
const _branchHours = [
  '23–01', '01–03', '03–05', '05–07', '07–09', '09–11',
  '11–13', '13–15', '15–17', '17–19', '19–21', '21–23',
];

// ---------------------------------------------------------------- 오행(五行)
// 0목 1화 2토 3금 4수. 상생 = +1, 상극 = +2 (mod 5).
const wuxingKor = ['목', '화', '토', '금', '수'];
const wuxingHanja = ['木', '火', '土', '金', '水'];
const wuxingTrait = ['성장·추진', '열정·표현', '안정·중용', '결단·규율', '지혜·유연'];

// 지지 오행: 자축인묘진사오미신유술해.
const _branchWuxing = [4, 2, 0, 0, 2, 1, 1, 2, 3, 3, 2, 4];

/// 천간 오행 index. 甲乙=木 … 壬癸=水.
int stemWuxing(int s) => s ~/ 2;

/// 지지 오행 index.
int branchWuxing(int b) => _branchWuxing[b];

/// 천간 음양 — 짝수 index = 양(陽).
bool stemYang(int s) => s % 2 == 0;

/// 지지 음양 — 짝수 index = 양(陽).
bool branchYang(int b) => b % 2 == 0;

// ---------------------------------------------------------------- 십신(十神)
/// 나(일간) 기준 상대 천간의 관계. 오상(五常) 그룹으로 묶어 쓴다.
enum TenGodGroup {
  bigyeop, // 比劫 — 자아·경쟁·동료·재물분배
  siksang, // 食傷 — 표현·재능·활동·발산
  jaeseong, // 財星 — 재물·현실성과·이성(남)
  gwanseong, // 官星 — 직장·규율·명예·이성(여)
  inseong, // 印星 — 학습·수용·보호·안정
}

const tenGodGroupKor = ['비겁', '식상', '재성', '관성', '인성'];

/// 일간(dayStem) 기준, 상대 오행(otherWuxing)의 십신 그룹.
TenGodGroup tenGodGroupOf(int dayStem, int otherWuxing) {
  final me = stemWuxing(dayStem);
  if (me == otherWuxing) return TenGodGroup.bigyeop;
  if ((me + 1) % 5 == otherWuxing) return TenGodGroup.siksang; // 내가 생함
  if ((me + 2) % 5 == otherWuxing) return TenGodGroup.jaeseong; // 내가 극함
  if ((otherWuxing + 2) % 5 == me) return TenGodGroup.gwanseong; // 나를 극함
  return TenGodGroup.inseong; // 나를 생함
}

/// 일간 기준, 상대 천간의 정확한 십신 이름(음양 구분).
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
/// 육합(六合) 짝. index → 합이 되는 지지 index.
const _yukhap = [1, 0, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2];

/// 육충(六沖): 상대 지지 index = (b + 6) % 12.
int chungOf(int b) => (b + 6) % 12;

/// 두 지지가 육합인가.
bool isHap(int a, int b) => _yukhap[a] == b;

/// 두 지지가 육충인가.
bool isChung(int a, int b) => chungOf(a) == b;

// ---------------------------------------------------------------- 기둥·차트
/// 사주 한 기둥(천간+지지).
class Pillar {
  const Pillar(this.stem, this.branch);
  final int stem; // 0~9
  final int branch; // 0~11

  String get hanja => '${stemHanja[stem]}${branchHanja[branch]}';
  String get kor => '${stemKor[stem]}${branchKor[branch]}';
  int get stemWx => stemWuxing(stem);
  int get branchWx => branchWuxing(branch);
}

/// 개인 사주 원국(原局).
class SajuChart {
  const SajuChart({
    required this.birth,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.hasHour,
  });

  final DateTime birth;
  final Pillar year;
  final Pillar month;
  final Pillar day;
  final Pillar? hour; // 시 모름이면 null
  final bool hasHour;

  /// 일간(日干) = '나'의 본원 천간 index.
  int get dayStem => day.stem;

  /// 원국의 모든 지지(합충 판정용).
  List<int> get branches =>
      [year.branch, month.branch, day.branch, if (hour != null) hour!.branch];

  /// 오행 분포(0~4 → 개수). 8글자(시 모름=6글자).
  Map<int, int> get wuxingCount {
    final m = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0};
    void add(int wx) => m[wx] = m[wx]! + 1;
    for (final p in [year, month, day, if (hour != null) hour!]) {
      add(p.stemWx);
      add(p.branchWx);
    }
    return m;
  }

  /// 가장 강한 오행 index.
  int get dominantWuxing {
    final c = wuxingCount;
    var best = 0;
    for (var i = 1; i < 5; i++) {
      if (c[i]! > c[best]!) best = i;
    }
    return best;
  }

  /// 가장 부족한 오행 index (동점이면 낮은 index).
  int get weakestWuxing {
    final c = wuxingCount;
    var worst = 0;
    for (var i = 1; i < 5; i++) {
      if (c[i]! < c[worst]!) worst = i;
    }
    return worst;
  }

  /// 신강/신약 대략 판정 — 일간을 돕는 오행(비겁+인성)의 비중.
  /// true=신강(자기 힘이 강함), false=신약.
  bool get isStrong {
    final me = stemWuxing(dayStem);
    final support = me; // 비겁(같은 오행)
    final resource = (me + 4) % 5; // 인성(나를 생하는 오행)
    final c = wuxingCount;
    final total = c.values.fold(0, (a, b) => a + b);
    final mine = c[support]! + c[resource]!;
    return mine * 2 >= total; // 절반 이상이면 신강
  }
}

/// 생년월일시 → 사주 원국. [hasHour]가 false면 시주 생략.
SajuChart computeSaju(DateTime birth, {required bool hasHour}) {
  final yi = yearGanziIndex(birth);
  final di = dayGanziIndex(birth);
  final year = Pillar(yi % 10, yi % 12);
  final month = Pillar(monthStemIndex(birth), monthBranchIndex(birth));
  final day = Pillar(di % 10, di % 12);
  Pillar? hour;
  if (hasHour) {
    final hb = hourBranchIndex(birth.hour);
    hour = Pillar(hourStemIndex(day.stem, hb), hb);
  }
  return SajuChart(
    birth: birth,
    year: year,
    month: month,
    day: day,
    hour: hour,
    hasHour: hasHour,
  );
}

/// 시지(時支) index — 자시 23:00~00:59 = 0, 이후 2시간마다.
int hourBranchIndex(int hour24) => ((hour24 + 1) ~/ 2) % 12;

/// 시간(時干) index — 오자시둔(五鼠遁). 甲己일→甲子시…
int hourStemIndex(int dayStem, int hourBranch) =>
    ((dayStem % 5) * 2 + hourBranch) % 10;

/// 시지 시간대 라벨 — 예: "23–01".
String hourRange(int branch) => _branchHours[branch];
