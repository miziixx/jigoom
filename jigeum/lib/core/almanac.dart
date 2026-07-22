import 'dart:math' as math;

/// 천문 역법 — 24절기(태양황경)·음력(삭·중기 정삭정기)·사주 절입.
///
/// 시각 기준: 한국 표준시(KST, UTC+9) 자정. 태양황경은 Meeus 저정밀 공식,
/// 삭(신월)은 Meeus 49장 공식. ΔT(~70초)는 무시 — 날짜 해상도엔 충분.
/// 절기·음력 모두 만세력(한국)과 대개 일치하나, 자정 근처 극히 드문 경계일은
/// 하루 차이가 날 수 있음.

const double _deg = math.pi / 180.0;
const double _kst = 9.0 / 24.0;

double _rad(double d) => d * _deg;

/// 그레고리력 → 율리우스일수(JDN, 정오 기준 정수).
int _gregToJDN(int y, int m, int d) {
  final a = (14 - m) ~/ 12;
  final yy = y + 4800 - a;
  final mm = m + 12 * a - 3;
  return d +
      ((153 * mm + 2) ~/ 5) +
      365 * yy +
      (yy ~/ 4) -
      (yy ~/ 100) +
      (yy ~/ 400) -
      32045;
}

/// KST 자정(JDN 날짜의)의 JD(UT).
double _kstMidnightJD(int dayNum) => dayNum - 0.5 - _kst;

/// 태양 겉보기 황경(도, 0~360). Meeus 저정밀.
double _sunLongitude(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
  final m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
  final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(_rad(m)) +
      (0.019993 - 0.000101 * t) * math.sin(_rad(2 * m)) +
      0.000289 * math.sin(_rad(3 * m));
  final trueLong = l0 + c;
  final omega = 125.04 - 1934.136 * t;
  var lambda = trueLong - 0.00569 - 0.00478 * math.sin(_rad(omega));
  lambda %= 360.0;
  if (lambda < 0) lambda += 360.0;
  return lambda;
}

/// KST civil DateTime(연·월·일·시·분) → JD(UT). 한국 표준시 UTC+9로 간주.
double julianDayUt(DateTime kst) {
  final ut = kst.subtract(const Duration(hours: 9));
  final jdn = _gregToJDN(ut.year, ut.month, ut.day);
  final dayFrac =
      (ut.hour + ut.minute / 60.0 + ut.second / 3600.0) / 24.0;
  return jdn - 0.5 + dayFrac;
}

/// 그 순간의 태양 겉보기 황경(도, 0~360). 별자리·트랜짓용.
double sunEclipticLongitude(DateTime kst) => _sunLongitude(julianDayUt(kst));

// ------------------------------------------------------------------ 24절기
// 인덱스 = 황경/15. 0°=춘분 … 345°=경칩.
const solarTermNames = [
  '춘분', '청명', '곡우', '입하', '소만', '망종',
  '하지', '소서', '대서', '입추', '처서', '백로',
  '추분', '한로', '상강', '입동', '소설', '대설',
  '동지', '소한', '대한', '입춘', '우수', '경칩',
];

/// dayNum(KST 하루) 안에서 태양황경이 15°의 배수를 지나면 그 절기 index, 없으면 null.
int? _termIndexOnDayNum(int dayNum) {
  final l0 = _sunLongitude(_kstMidnightJD(dayNum));
  var l1 = _sunLongitude(_kstMidnightJD(dayNum + 1));
  var a = l0;
  var b = l1;
  if (b < a) b += 360.0; // 360° 넘어가는 경계
  final firstK = (a / 15.0).floor() + 1;
  final kd = firstK * 15.0;
  if (kd > a && kd <= b) return ((firstK % 24) + 24) % 24;
  return null;
}

/// 그 날짜의 절기 index(0~23) 또는 null.
int? solarTermIndexOn(DateTime d) =>
    _termIndexOnDayNum(_gregToJDN(d.year, d.month, d.day));

/// 그 날짜의 절기 이름 또는 null. 예: "하지".
String? solarTermName(DateTime d) {
  final i = solarTermIndexOn(d);
  return i == null ? null : solarTermNames[i];
}

// -------------------------------------------------------------- 사주 절입
/// 절기 기준 월지(月支) index(자=0). 寅월은 입춘(315°)부터.
int sajuMonthBranch(DateTime d) {
  final lam =
      _sunLongitude(_kstMidnightJD(_gregToJDN(d.year, d.month, d.day)));
  final m = ((lam - 315.0) % 360.0) / 30.0; // 0=寅 … 11=丑
  return (2 + m.floor()) % 12;
}

/// 입춘(315°) 이전인가 — 년주(年柱) 경계.
bool beforeIpchun(DateTime d) {
  if (d.month > 2) return false;
  final lam =
      _sunLongitude(_kstMidnightJD(_gregToJDN(d.year, d.month, d.day)));
  return lam < 315.0;
}

// ------------------------------------------------------------------- 음력(삭)
/// k번째 삭(신월)의 JDE(역학시). Meeus 49장.
double _newMoonJDE(int k) {
  final t = k / 1236.85;
  final t2 = t * t, t3 = t2 * t, t4 = t3 * t;
  var jde = 2451550.09766 +
      29.530588861 * k +
      0.00015437 * t2 -
      0.000000150 * t3 +
      0.00000000073 * t4;
  final e = 1 - 0.002516 * t - 0.0000074 * t2;
  final m = _rad((2.5534 + 29.1053567 * k - 0.0000014 * t2 - 0.00000011 * t3) %
      360.0);
  final mp = _rad((201.5643 +
          385.81693528 * k +
          0.0107582 * t2 +
          0.00001238 * t3 -
          0.000000058 * t4) %
      360.0);
  final f = _rad((160.7108 +
          390.67050284 * k -
          0.0016118 * t2 -
          0.00000227 * t3 +
          0.000000011 * t4) %
      360.0);
  final om =
      _rad((124.7746 - 1.56375588 * k + 0.0020672 * t2 + 0.00000215 * t3) %
          360.0);
  jde += -0.40720 * math.sin(mp) +
      0.17241 * e * math.sin(m) +
      0.01608 * math.sin(2 * mp) +
      0.01039 * math.sin(2 * f) +
      0.00739 * e * math.sin(mp - m) +
      -0.00514 * e * math.sin(mp + m) +
      0.00208 * e * e * math.sin(2 * m) +
      -0.00111 * math.sin(mp - 2 * f) +
      -0.00057 * math.sin(mp + 2 * f) +
      0.00056 * e * math.sin(2 * mp + m) +
      -0.00042 * math.sin(3 * mp) +
      0.00042 * e * math.sin(m + 2 * f) +
      0.00038 * e * math.sin(m - 2 * f) +
      -0.00024 * e * math.sin(2 * mp - m) +
      -0.00017 * math.sin(om) +
      -0.00007 * math.sin(mp + 2 * m) +
      0.00004 * math.sin(2 * mp - 2 * f) +
      0.00004 * math.sin(3 * m) +
      0.00003 * math.sin(mp + m - 2 * f) +
      0.00003 * math.sin(2 * mp + 2 * f) +
      -0.00003 * math.sin(mp + m + 2 * f) +
      0.00003 * math.sin(mp - m + 2 * f) +
      -0.00002 * math.sin(mp - m - 2 * f) +
      -0.00002 * math.sin(3 * mp + m) +
      0.00002 * math.sin(4 * mp);
  final a1 = _rad((299.77 + 0.107408 * k - 0.009173 * t2) % 360.0);
  final a2 = _rad((251.88 + 0.016321 * k) % 360.0);
  final a3 = _rad((251.83 + 26.651886 * k) % 360.0);
  final a4 = _rad((349.42 + 36.412478 * k) % 360.0);
  final a5 = _rad((84.66 + 18.206239 * k) % 360.0);
  final a6 = _rad((141.74 + 53.303771 * k) % 360.0);
  final a7 = _rad((207.14 + 2.453732 * k) % 360.0);
  final a8 = _rad((154.84 + 7.30686 * k) % 360.0);
  final a9 = _rad((34.52 + 27.261239 * k) % 360.0);
  final a10 = _rad((207.19 + 0.121824 * k) % 360.0);
  final a11 = _rad((291.34 + 1.844379 * k) % 360.0);
  final a12 = _rad((161.72 + 24.198154 * k) % 360.0);
  final a13 = _rad((239.56 + 25.513099 * k) % 360.0);
  final a14 = _rad((331.55 + 3.592518 * k) % 360.0);
  jde += 0.000325 * math.sin(a1) +
      0.000165 * math.sin(a2) +
      0.000164 * math.sin(a3) +
      0.000126 * math.sin(a4) +
      0.000110 * math.sin(a5) +
      0.000062 * math.sin(a6) +
      0.000060 * math.sin(a7) +
      0.000056 * math.sin(a8) +
      0.000047 * math.sin(a9) +
      0.000042 * math.sin(a10) +
      0.000040 * math.sin(a11) +
      0.000037 * math.sin(a12) +
      0.000035 * math.sin(a13) +
      0.000023 * math.sin(a14);
  return jde;
}

/// 삭 JDE → KST civil day의 JDN.
int _newMoonDayNum(int k) => (_newMoonJDE(k) + 0.5 + _kst).floor();

/// dayNum 이하(포함)로 가장 가까운 삭의 lunation 번호 k.
int _newMoonKOnOrBefore(int dayNum) {
  var k = ((dayNum - 2451550) / 29.530588861).floor();
  while (_newMoonDayNum(k) > dayNum) {
    k--;
  }
  while (_newMoonDayNum(k + 1) <= dayNum) {
    k++;
  }
  return k;
}

/// lunation k(삭~다음 삭) 안에 중기(中氣, 황경 30°의 배수)가 있는가.
bool _hasZhongqi(int k) {
  var a = _sunLongitude(_newMoonJDE(k));
  var b = _sunLongitude(_newMoonJDE(k + 1));
  if (b < a) b += 360.0;
  final firstK = (a / 30.0).floor() + 1;
  final kd = firstK * 30.0;
  return kd > a && kd <= b;
}

/// 그 해 동지(冬至, 황경 270°)의 dayNum. 12월 20~24 스캔.
int _winterSolsticeDayNum(int gYear) {
  for (var d = 20; d <= 24; d++) {
    if (_termIndexOnDayNum(_gregToJDN(gYear, 12, d)) == 18) {
      return _gregToJDN(gYear, 12, d);
    }
  }
  return _gregToJDN(gYear, 12, 22);
}

/// 음력 날짜.
class Lunar {
  const Lunar(this.year, this.month, this.day, this.leap);
  final int year;
  final int month;
  final int day;
  final bool leap; // 윤달
}

/// 그레고리 날짜 → 음력(정삭정기, 중기 무배치 윤달 규칙).
Lunar lunarOf(DateTime g) {
  final dayNum = _gregToJDN(g.year, g.month, g.day);
  final k = _newMoonKOnOrBefore(dayNum);
  final lday = dayNum - _newMoonDayNum(k) + 1;

  // 월 번호 기준점: 동지를 품은 달 = 11월.
  var sol = _winterSolsticeDayNum(g.year);
  var anchorYear = g.year;
  if (dayNum < sol) {
    sol = _winterSolsticeDayNum(g.year - 1);
    anchorYear = g.year - 1;
  }
  final k11 = _newMoonKOnOrBefore(sol);
  final k11n = _newMoonKOnOrBefore(_winterSolsticeDayNum(anchorYear + 1));
  final leapYear = (k11n - k11) == 13;

  int? leapK;
  if (leapYear) {
    for (var kk = k11 + 1; kk < k11n; kk++) {
      if (!_hasZhongqi(kk)) {
        leapK = kk;
        break;
      }
    }
  }

  var num = 11;
  var isLeap = false;
  for (var kk = k11 + 1; kk <= k; kk++) {
    if (leapK != null && kk == leapK) {
      isLeap = true; // 번호 유지, 윤달
    } else {
      num = num % 12 + 1;
      isLeap = false;
    }
  }

  final lunarYear = num >= 11 ? anchorYear : anchorYear + 1;
  return Lunar(lunarYear, num, lday, isLeap);
}

/// 음력 라벨 — 예: "음력 6월 8일", 윤달이면 "음력 윤5월 3일".
String lunarLabel(DateTime d) {
  final l = lunarOf(d);
  return '음력 ${l.leap ? '윤' : ''}${l.month}월 ${l.day}일';
}

/// 음력 짧은 라벨(달력 칸용) — 1일이면 "6월", 그 외 "8". 윤달은 "윤6월".
String lunarShort(DateTime d) {
  final l = lunarOf(d);
  if (l.day == 1) return '${l.leap ? '윤' : ''}${l.month}월';
  return '${l.day}';
}

/// 음력(년·월·일·윤달) → 양력 그레고리 날짜. `lunarOf`를 역스캔한다.
/// [leap]이 그 해에 없으면 같은 달의 평달로 대체(null 아님). 못 찾으면 null.
DateTime? solarFromLunar(int year, int month, int day, bool leap) {
  var d = DateTime(year - 1, 11, 1);
  final end = DateTime(year + 1, 3, 1);
  DateTime? plainFallback;
  while (d.isBefore(end)) {
    final l = lunarOf(d);
    if (l.year == year && l.month == month && l.day == day) {
      if (l.leap == leap) return d;
      if (!l.leap) plainFallback ??= d;
    }
    d = d.add(const Duration(days: 1));
  }
  return plainFallback; // 윤달 요청이 무효면 평달로
}
