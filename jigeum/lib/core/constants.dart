import 'package:flutter/material.dart';

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

/// 라벨·기호·영문·숫자용 모노스페이스. (JetBrains Mono 미번들 → generic monospace)
const kMonoFamily = 'monospace';

/// 한글 본문·제목용 산세리프. null = 기기 기본 글꼴(삼성 One UI 등).
const String? kSansFamily = null;

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

// ------------------------------------------------------------- 별자리(점성술)
// 서양 태양(sun-sign) 점성술. 월별 경계일(_zodiacCut) 기준으로 별자리 index 산출.
// index: 0 물병 … 11 염소 (월 순서에 맞춘 배열).
const _zodiacCut = [20, 19, 21, 20, 21, 22, 23, 23, 23, 23, 23, 22];
const _zodiacNames = [
  '물병자리', '물고기자리', '양자리', '황소자리', '쌍둥이자리', '게자리',
  '사자자리', '처녀자리', '천칭자리', '전갈자리', '사수자리', '염소자리',
];
const _zodiacSymbol = ['♒', '♓', '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑'];
const _zodiacEng = [
  'Aquarius', 'Pisces', 'Aries', 'Taurus', 'Gemini', 'Cancer',
  'Leo', 'Virgo', 'Libra', 'Scorpio', 'Sagittarius', 'Capricorn',
];
const _zodiacRange = [
  '1.20–2.18', '2.19–3.20', '3.21–4.19', '4.20–5.20', '5.21–6.21', '6.22–7.22',
  '7.23–8.22', '8.23–9.22', '9.23–10.22', '10.23–11.22', '11.23–12.21', '12.22–1.19',
];
const _zodiacElement = ['공기', '물', '불', '흙', '공기', '물', '불', '흙', '공기', '물', '불', '흙'];
const _zodiacPlanet = [
  '천왕성', '해왕성', '화성', '금성', '수성', '달',
  '태양', '수성', '금성', '명왕성', '목성', '토성',
];

/// 별자리 데이터 묶음.
class Zodiac {
  const Zodiac(this.name, this.symbol, this.eng, this.range, this.element,
      this.planet);
  final String name; // 게자리
  final String symbol; // ♋
  final String eng; // Cancer
  final String range; // 6.22–7.22
  final String element; // 물
  final String planet; // 달
}

int _zodiacIndex(DateTime d) {
  final m = d.month;
  return d.day >= _zodiacCut[m - 1] ? m - 1 : (m - 2 + 12) % 12;
}

/// 날짜의 별자리 데이터 — 서양 태양 별자리(점성술).
Zodiac zodiacOf(DateTime d) {
  final i = _zodiacIndex(d);
  return Zodiac(_zodiacNames[i], _zodiacSymbol[i], _zodiacEng[i],
      _zodiacRange[i], _zodiacElement[i], _zodiacPlanet[i]);
}

/// 날짜의 별자리 — 예: "게자리".
String byeoljari(DateTime d) => _zodiacNames[_zodiacIndex(d)];

/// 별자리 기호 라벨 — 예: "♋ 게자리".
String byeoljariLabel(DateTime d) {
  final i = _zodiacIndex(d);
  return '${_zodiacSymbol[i]} ${_zodiacNames[i]}';
}
