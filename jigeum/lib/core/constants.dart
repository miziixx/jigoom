import 'package:flutter/material.dart';

import 'almanac.dart';

/// 간격 토큰 (4px 리듬 + 편집 레이아웃 상수). DESIGN_SYSTEM §2.
class AppSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s8 = 48.0;

  /// 편집 gutter — 화면 좌우 여백. 잡지 마진의 시그니처. (22px)
  static const gutter = 22.0;
}

/// 각진 모서리가 편집 시그니처. (DESIGN_SYSTEM §4)
const double kRadius = 0.0;

/// 라벨·기호·영문·숫자용 모노스페이스 fallback.
const kMonoFamily = 'monospace';

/// 한글 본문·제목용 기본값. null 이면 Flutter/플랫폼 기본 글꼴을 사용하므로
/// 폰에서 적용 중인 시스템 글꼴 계열을 가장 자연스럽게 따라간다.
const String? kSansFamily = null;

/// 제목/헤딩용 세리프(명조). v17 에디토리얼 시그니처 — 얇은 세리프 제목.
/// 본문·라벨은 산세리프를 유지하고 헤딩만 이 글꼴을 쓴다.
const String kSerifFamily = 'NanumMyeongjo';

/// 사용자가 고를 수 있는 번들 한글 글꼴.
/// 앱 전체 톤이 흔들리지 않도록 본문용 고딕 계열만 노출한다.
class AppFont {
  const AppFont(this.key, this.name, this.family, this.sample,
      [this.oneWeight = false]);
  final String key; // 저장용 키
  final String name; // 표시 이름
  final String family; // pubspec fonts family
  final String sample; // 미리보기 문구
  final bool oneWeight; // 굵기가 하나뿐(굵기 슬라이더 영향 없음)
}

const kDefaultFontKey = 'pretendard';

const List<AppFont> kFonts = [
  AppFont('pretendard', '프리텐다드', 'Pretendard', '가나다 AaBb 123'),
  AppFont('nanum', '나눔고딕', 'NanumGothic', '가나다 AaBb 123'),
  AppFont('myeongjo', '나눔명조', 'NanumMyeongjo', '가나다 AaBb 123'),
  AppFont('gowun', '고운돋움', 'GowunDodum', '가나다 AaBb 123', true),
];

/// 폰트 키 → pubspec family. 알 수 없으면 기본(Pretendard).
String familyForFontKey(String key) {
  for (final f in kFonts) {
    if (f.key == key) return f.family;
  }
  return 'Pretendard';
}

const kAnimDuration = Duration(milliseconds: 160);
const kAnimCurve = Curves.easeOut;

/// 굵기 조절: FontWeight 을 delta 만큼 이동 (w400=index3 기준).
FontWeight shiftWeight(FontWeight base, int delta) {
  const order = [
    FontWeight.w100,
    FontWeight.w200,
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
    FontWeight.w900,
  ];
  final i = (order.indexOf(base) + delta).clamp(0, order.length - 1);
  return order[i];
}

/// 노드 타입
class NodeType {
  static const goal = 'goal';
  static const task = 'task';
  static const memo = 'memo';
  static const folder = 'folder'; // 카테고리/폴더
}

/// 노드 상태
class NodeStatus {
  static const open = 'open';
  static const done = 'done';
  static const drawer = 'drawer';
}

/// 하루의 구간 (오전/오후/저녁)
class Slot {
  static const am = 'am';
  static const pm = 'pm';
  static const eve = 'eve';

  static const all = [am, pm, eve];

  static String label(String slot) {
    switch (slot) {
      case am:
        return '오전';
      case pm:
        return '오후';
      case eve:
        return '저녁';
      default:
        return '';
    }
  }
}

/// 날짜 유틸: 자정 기준 날짜만 남김.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime todayDate() => dateOnly(DateTime.now());

/// 매트릭스 상단 기간 필터. 기본은 [today] — "오늘만".
enum MatrixRange {
  today('오늘'),
  week('이번 주'),
  month('이번 달'),
  all('전체');

  const MatrixRange(this.label);
  final String label;

  /// 이 기간의 날짜 범위(양끝 포함). [all] 은 null = 제한 없음.
  ({DateTime from, DateTime to})? span(DateTime today) {
    final d = dateOnly(today);
    switch (this) {
      case MatrixRange.today:
        return (from: d, to: d);
      case MatrixRange.week:
        final start = d.subtract(Duration(days: d.weekday - 1)); // 월요일
        return (from: start, to: start.add(const Duration(days: 6)));
      case MatrixRange.month:
        final start = DateTime(d.year, d.month, 1);
        final end = DateTime(d.year, d.month + 1, 0);
        return (from: start, to: end);
      case MatrixRange.all:
        return null;
    }
  }
}

// ------------------------------------------------------------------ 일진(日辰)
// 날짜의 60갑자(천간+지지). 기준: 2000-01-07 = 갑자(甲子, index 0).
// (교차검증: 1900-01-01 = 갑술 과 일치)
const _cheongan = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
const _jiji = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];
const _cheonganHanja = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
const _jijiHanja = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];

int _ganziIndex(DateTime d) {
  // DST 영향 없이 순수 일수 차이 (UTC 자정 기준).
  final anchor = DateTime.utc(2000, 1, 7);
  final x = DateTime.utc(d.year, d.month, d.day);
  final diff = x.difference(anchor).inDays;
  return ((diff % 60) + 60) % 60;
}

/// 일진 한글 — 예: "정유일".
String iljin(DateTime d) {
  final i = _ganziIndex(d);
  return '${_cheongan[i % 10]}${_jiji[i % 12]}일';
}

/// 일진 한자 — 예: "丁酉".
String iljinHanja(DateTime d) {
  final i = _ganziIndex(d);
  return '${_cheonganHanja[i % 10]}${_jijiHanja[i % 12]}';
}

/// 일진 한자 라벨 — 예: "丁酉日".
String iljinLabel(DateTime d) => '${iljinHanja(d)}日';

/// 일주(日柱) 60갑자 index (0~59) — 사주 계산용. 천간=%10, 지지=%12.
int dayGanziIndex(DateTime d) => _ganziIndex(d);

// ----------------------------------------------------------- 년주·월주(만세력)
// 년주(年柱)는 입춘(~2/4) 이전이면 전년 간지. 월주(月柱)는 절기(節) 기준 +
// 오호둔(五虎遁)으로 천간 산출. 절기일은 ±1일 오차가 있는 근사값.

/// 60갑자 중 올해(년주) index. 입춘(315°) 이전은 전년.
int _yearGanziIndex(DateTime d) {
  var y = d.year;
  if (beforeIpchun(d)) y -= 1;
  return (((y - 4) % 60) + 60) % 60;
}

/// 절기(節) 기준 이 날짜가 속한 월지(月支) index (자=0). 태양황경 기준.
int _monthBranch(DateTime d) => sajuMonthBranch(d);

/// 년주 한자 — 예: "丙午".
String yearGanziHanja(DateTime d) {
  final i = _yearGanziIndex(d);
  return '${_cheonganHanja[i % 10]}${_jijiHanja[i % 12]}';
}

/// 년주 라벨 — 예: "丙午年".
String yearLabel(DateTime d) => '${yearGanziHanja(d)}年';

/// 월주 한자 — 오호둔으로 월간 산출. 예: "乙未".
String monthGanziHanja(DateTime d) {
  final yStem = _yearGanziIndex(d) % 10;
  final branch = _monthBranch(d);
  final yinStem = (yStem % 5) * 2 + 2; // 寅월 천간 (오호둔)
  final order = ((branch - 2) + 12) % 12; // 寅부터의 순번
  final stem = (yinStem + order) % 10;
  return '${_cheonganHanja[stem]}${_jijiHanja[branch]}';
}

/// 월주 라벨 — 예: "乙未月".
String monthLabel(DateTime d) => '${monthGanziHanja(d)}月';

/// 년·월·일 한자 라벨 — 예: "丙午年 乙未月 丁酉日".
String sajuLabel(DateTime d) =>
    '${yearLabel(d)} ${monthLabel(d)} ${iljinLabel(d)}';

/// 년주(年柱) 60갑자 index — 입춘 이전은 전년. 천간=%10, 지지=%12.
int yearGanziIndex(DateTime d) => _yearGanziIndex(d);

/// 월주(月柱) 천간 index — 오호둔(五虎遁).
int monthStemIndex(DateTime d) {
  final yStem = _yearGanziIndex(d) % 10;
  final branch = sajuMonthBranch(d);
  final yinStem = (yStem % 5) * 2 + 2; // 寅월 천간
  final order = ((branch - 2) + 12) % 12; // 寅부터의 순번
  return (yinStem + order) % 10;
}

/// 월주(月柱) 지지 index — 절기 기준.
int monthBranchIndex(DateTime d) => sajuMonthBranch(d);

// ------------------------------------------------------------- 별자리(점성술)
// 서양 태양(sun-sign) 점성술. 월별 경계일(_zodiacCut) 기준으로 별자리 index 산출.
// index: 0 물병 … 11 염소 (월 순서에 맞춘 배열).
const _zodiacCut = [20, 19, 21, 20, 21, 22, 23, 23, 23, 23, 23, 22];
const _zodiacNames = [
  '물병자리',
  '물고기자리',
  '양자리',
  '황소자리',
  '쌍둥이자리',
  '게자리',
  '사자자리',
  '처녀자리',
  '천칭자리',
  '전갈자리',
  '사수자리',
  '염소자리',
];
const _zodiacSymbol = [
  '♒',
  '♓',
  '♈',
  '♉',
  '♊',
  '♋',
  '♌',
  '♍',
  '♎',
  '♏',
  '♐',
  '♑'
];
const _zodiacEng = [
  'Aquarius',
  'Pisces',
  'Aries',
  'Taurus',
  'Gemini',
  'Cancer',
  'Leo',
  'Virgo',
  'Libra',
  'Scorpio',
  'Sagittarius',
  'Capricorn',
];
const _zodiacRange = [
  '1.20–2.18',
  '2.19–3.20',
  '3.21–4.19',
  '4.20–5.20',
  '5.21–6.21',
  '6.22–7.22',
  '7.23–8.22',
  '8.23–9.22',
  '9.23–10.22',
  '10.23–11.22',
  '11.23–12.21',
  '12.22–1.19',
];
const _zodiacElement = [
  '공기',
  '물',
  '불',
  '흙',
  '공기',
  '물',
  '불',
  '흙',
  '공기',
  '물',
  '불',
  '흙'
];
const _zodiacPlanet = [
  '천왕성',
  '해왕성',
  '화성',
  '금성',
  '수성',
  '달',
  '태양',
  '수성',
  '금성',
  '명왕성',
  '목성',
  '토성',
];
// 황도 12궁 한자 (중국 점성 명칭).
const _zodiacHanja = [
  '寶瓶',
  '雙魚',
  '白羊',
  '金牛',
  '雙子',
  '巨蟹',
  '獅子',
  '處女',
  '天秤',
  '天蠍',
  '人馬',
  '磨羯',
];

/// 별자리 데이터 묶음.
class Zodiac {
  const Zodiac(this.name, this.symbol, this.eng, this.range, this.element,
      this.planet, this.hanja);
  final String name; // 게자리
  final String symbol; // ♋
  final String eng; // Cancer
  final String range; // 6.22–7.22
  final String element; // 물
  final String planet; // 달
  final String hanja; // 巨蟹
}

Zodiac _zodiacAt(int i) => Zodiac(
    _zodiacNames[i],
    _zodiacSymbol[i],
    _zodiacEng[i],
    _zodiacRange[i],
    _zodiacElement[i],
    _zodiacPlanet[i],
    _zodiacHanja[i]);

int _zodiacIndex(DateTime d) {
  final m = d.month;
  return d.day >= _zodiacCut[m - 1] ? m - 1 : (m - 2 + 12) % 12;
}

/// 날짜의 별자리 데이터 — 서양 태양 별자리(점성술).
Zodiac zodiacOf(DateTime d) => _zodiacAt(_zodiacIndex(d));

/// 지금 상승궁(어센던트) index — 근사: 일출(~6시)에 태양궁이 뜨고 약 2h마다 1궁.
/// 정확한 상승궁은 출생 시각·위도가 필요 → 여기선 '지금 하늘'의 근사값.
int _risingIndex(DateTime d) {
  final sun = _zodiacIndex(d);
  final steps = ((d.hour - 6) / 2).floor();
  return ((sun + steps) % 12 + 12) % 12;
}

/// 지금 상승궁(어센던트, 근사).
Zodiac risingOf(DateTime d) => _zodiacAt(_risingIndex(d));

/// 지금 하강궁(디센던트) — 상승궁의 반대 궁.
Zodiac descendantOf(DateTime d) => _zodiacAt((_risingIndex(d) + 6) % 12);

/// 날짜의 별자리 — 예: "게자리".
String byeoljari(DateTime d) => _zodiacNames[_zodiacIndex(d)];

/// 별자리 기호 라벨 — 예: "♋ 게자리".
String byeoljariLabel(DateTime d) {
  final i = _zodiacIndex(d);
  return '${_zodiacSymbol[i]} ${_zodiacNames[i]}';
}
