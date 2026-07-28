import 'dart:math' as math;

import 'almanac.dart';
import 'explain.dart';

/// 서양 점성술 엔진 — 오프라인. 태양·달 별자리를 실제 천문 계산(황경)으로 정확히
/// 산출하고, 출생 시각·지역이 있으면 상승궁(어센던트)을 위도 기반으로 근사한다.
///
/// 태양황경은 almanac(Meeus 저정밀)을 재사용, 달황경은 Meeus 47장 축약항으로 계산한다
/// (별자리 판정엔 <0.5° 오차로 충분). 상승궁은 평항성시·고정 황도경사 기반 근사다.
/// 모두 순수 함수라 같은 입력엔 항상 같은 결과가 나온다.

const double _deg = math.pi / 180.0;
double _rad(double d) => d * _deg;
double _norm360(double x) {
  var v = x % 360.0;
  if (v < 0) v += 360.0;
  return v;
}

// ------------------------------------------------------------------ 별자리 정의
// 황도 순서(양자리 0° 시작). index = 황경 ~/ 30.
enum Element { fire, earth, air, water }

const _elementKor = ['불', '흙', '공기', '물'];
String elementKor(Element e) => _elementKor[e.index];

class SignInfo {
  const SignInfo(this.name, this.symbol, this.eng, this.element, this.mode,
      this.ruler, this.keyword, this.persona);
  final String name; // 양자리
  final String symbol; // ♈
  final String eng; // Aries
  final Element element;
  final String mode; // 활동/고정/변통
  final String ruler; // 지배성
  final String keyword; // 한 단어 성향
  final String persona; // 성격 설명
}

const _signs = <SignInfo>[
  SignInfo('양자리', '♈', 'Aries', Element.fire, '활동', '화성', '개척',
      '먼저 나서서 시작하는 힘이 강해요. 솔직하고 추진력이 좋지만, 급한 마음은 다스릴수록 이득이에요.'),
  SignInfo('황소자리', '♉', 'Taurus', Element.earth, '고정', '금성', '안정',
      '한번 정하면 꾸준히 밀고 가요. 감각이 좋고 현실적이며, 서두르지 않는 뚝심이 큰 자산이에요.'),
  SignInfo('쌍둥이자리', '♊', 'Gemini', Element.air, '변통', '수성', '소통',
      '호기심이 많고 말과 정보에 빨라요. 여러 가지를 동시에 즐기되, 하나를 끝까지 붙드는 힘을 더하면 좋아요.'),
  SignInfo('게자리', '♋', 'Cancer', Element.water, '활동', '달', '보살핌',
      '정이 깊고 사람을 잘 돌봐요. 내 편을 소중히 여기며, 마음의 안전함을 무엇보다 중요하게 느껴요.'),
  SignInfo('사자자리', '♌', 'Leo', Element.fire, '고정', '태양', '표현',
      '밝고 당당하며 주목받을 때 빛나요. 마음이 넓고 베풀기를 좋아하니, 자존심만 부드럽게 다루면 돼요.'),
  SignInfo('처녀자리', '♍', 'Virgo', Element.earth, '변통', '수성', '정돈',
      '꼼꼼하고 분석이 뛰어나요. 작은 것까지 챙기는 성실함이 강점이며, 완벽주의는 조금 내려놓아도 괜찮아요.'),
  SignInfo('천칭자리', '♎', 'Libra', Element.air, '활동', '금성', '조화',
      '균형과 관계를 소중히 여겨요. 세련되고 공정하려 애쓰며, 결정을 미루기보다 기준을 정하면 편해져요.'),
  SignInfo('전갈자리', '♏', 'Scorpio', Element.water, '고정', '명왕성', '몰입',
      '한번 마음을 주면 깊고 강렬해요. 통찰력이 뛰어나고 비밀을 잘 지키며, 집중력이 무기예요.'),
  SignInfo('사수자리', '♐', 'Sagittarius', Element.fire, '변통', '목성', '탐험',
      '자유롭고 낙천적이며 넓게 봐요. 배움과 여행을 즐기고, 솔직함에 따뜻함을 얹으면 더 좋아요.'),
  SignInfo('염소자리', '♑', 'Capricorn', Element.earth, '활동', '토성', '성취',
      '책임감이 강하고 목표를 향해 오래 참아요. 현실을 단단히 쌓아 올리는 힘이 있어요.'),
  SignInfo('물병자리', '♒', 'Aquarius', Element.air, '고정', '천왕성', '독창',
      '자기만의 시각이 뚜렷하고 자유로워요. 새롭고 공정한 것을 좋아하며, 사람을 편견 없이 대해요.'),
  SignInfo('물고기자리', '♓', 'Pisces', Element.water, '변통', '해왕성', '공감',
      '감수성이 풍부하고 따뜻해요. 남의 마음을 잘 헤아리며, 상상력과 예술적 감각이 뛰어나요.'),
];

SignInfo signAt(int i) => _signs[((i % 12) + 12) % 12];

/// 황경(도) → 별자리 index(0=양자리 … 11=물고기자리).
int signIndexFromLongitude(double lng) => (_norm360(lng) / 30.0).floor() % 12;

// ------------------------------------------------------------------ 달황경
/// 그 순간 달의 겉보기 황경(도). Meeus 47장 주요 축약항(별자리 판정용).
double moonEclipticLongitude(DateTime kst) {
  final jd = julianDayUt(kst);
  final t = (jd - 2451545.0) / 36525.0;
  final lp = 218.3164477 +
      481267.88123421 * t -
      0.0015786 * t * t +
      t * t * t / 538841.0;
  final d = 297.8501921 + 445267.1114034 * t - 0.0018819 * t * t;
  final m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t * t;
  final mp = 134.9633964 +
      477198.8675055 * t +
      0.0087414 * t * t +
      t * t * t / 69699.0;
  final f = 93.2720950 +
      483202.0175233 * t -
      0.0036539 * t * t -
      t * t * t / 3526000.0;
  final e = 1 - 0.002516 * t - 0.0000074 * t * t;
  double s(double x) => math.sin(_rad(x));
  // 진폭 단위 1e-6도. 큰 항 위주(정밀도 ~0.1~0.3°).
  final sum = 6288774 * s(mp) +
      1274027 * s(2 * d - mp) +
      658314 * s(2 * d) +
      213618 * s(2 * mp) +
      -185116 * e * s(m) +
      -114332 * s(2 * f) +
      58793 * s(2 * d - 2 * mp) +
      57066 * e * s(2 * d - m - mp) +
      53322 * s(2 * d + mp) +
      45758 * e * s(2 * d - m) +
      -40923 * e * s(m - mp) +
      -34720 * s(d) +
      -30383 * e * s(m + mp) +
      15327 * s(2 * d - 2 * f) +
      -12528 * s(mp + 2 * f) +
      10980 * s(mp - 2 * f) +
      10675 * s(4 * d - mp) +
      10034 * s(3 * mp) +
      8548 * s(4 * d - 2 * mp);
  return _norm360(lp + sum / 1000000.0);
}

// ------------------------------------------------------------------ 상승궁
/// 출생 시각·위도·경도로 상승궁(어센던트) 별자리 index를 근사한다.
int ascendantSignIndex(DateTime kstBirth, double latDeg, double lngEastDeg) {
  final jd = julianDayUt(kstBirth);
  final t = (jd - 2451545.0) / 36525.0;
  final gmst = _norm360(280.46061837 +
      360.98564736629 * (jd - 2451545.0) +
      0.000387933 * t * t -
      t * t * t / 38710000.0);
  final lst = _norm360(gmst + lngEastDeg); // 지방 항성시(도)
  final eps = _rad(23.439291 - 0.0130042 * t);
  final ramc = _rad(lst);
  final phi = _rad(latDeg);
  final asc = math.atan2(math.cos(ramc),
      -(math.sin(ramc) * math.cos(eps) + math.tan(phi) * math.sin(eps)));
  return signIndexFromLongitude(asc / _deg);
}

// ------------------------------------------------------------------ 차트
class AstroChart {
  const AstroChart({
    required this.sun,
    required this.moon,
    required this.rising,
    required this.hasTime,
    required this.hasPlace,
    required this.elementCount,
  });

  final int sun; // 태양 별자리 index
  final int moon; // 달 별자리 index
  final int? rising; // 상승궁 index (시각·지역 없으면 null)
  final bool hasTime;
  final bool hasPlace;
  final Map<Element, int> elementCount; // 태양·달·(상승) 원소 집계

  SignInfo get sunSign => signAt(sun);
  SignInfo get moonSign => signAt(moon);
  SignInfo? get risingSign => rising == null ? null : signAt(rising!);

  Element get dominantElement {
    var best = Element.fire;
    for (final e in Element.values) {
      if (elementCount[e]! > elementCount[best]!) best = e;
    }
    return best;
  }

  Element? get lackingElement {
    Element? worst;
    for (final e in Element.values) {
      if (elementCount[e] == 0) {
        worst ??= e;
      }
    }
    return worst;
  }
}

/// 출생 정보로 개인 점성 차트를 만든다. [birth]는 KST civil 시각.
AstroChart computeAstroChart(
  DateTime birth, {
  required bool hasTime,
  double? latitude,
  double? longitude,
}) {
  // 시각을 모르면 정오로 달·상승을 근사(달은 하루 ~13° 이동 → 근사 표시).
  final instant = hasTime
      ? birth
      : DateTime(birth.year, birth.month, birth.day, 12, 0);
  final sun = signIndexFromLongitude(sunEclipticLongitude(instant));
  final moon = signIndexFromLongitude(moonEclipticLongitude(instant));
  final hasPlace = latitude != null && longitude != null;
  final rising = (hasTime && hasPlace)
      ? ascendantSignIndex(birth, latitude!, longitude!)
      : null;

  final count = {for (final e in Element.values) e: 0};
  count[signAt(sun).element] = count[signAt(sun).element]! + 1;
  count[signAt(moon).element] = count[signAt(moon).element]! + 1;
  if (rising != null) {
    count[signAt(rising).element] = count[signAt(rising).element]! + 1;
  }

  return AstroChart(
    sun: sun,
    moon: moon,
    rising: rising,
    hasTime: hasTime,
    hasPlace: hasPlace,
    elementCount: count,
  );
}

// ------------------------------------------------------------------ 오늘의 하늘
class TodaySky {
  const TodaySky(this.sun, this.moon);
  final int sun;
  final int moon;
  SignInfo get sunSign => signAt(sun);
  SignInfo get moonSign => signAt(moon);
}

TodaySky computeTodaySky(DateTime now) => TodaySky(
      signIndexFromLongitude(sunEclipticLongitude(now)),
      signIndexFromLongitude(moonEclipticLongitude(now)),
    );

// ------------------------------------------------------------------ 풀이(레벨)
/// 화면에 그대로 뿌릴 점성 풀이 카드 하나.
class AstroReading {
  const AstroReading({
    required this.key,
    required this.title,
    required this.glyph,
    required this.summary,
    required this.body,
    this.note,
  });
  final String key;
  final String title;
  final String glyph;
  final String summary;
  final List<String> body;
  final String? note;
}

String _elementTrait(Element e) => switch (e) {
      Element.fire => '열정과 추진 — 먼저 움직이고 표현하는',
      Element.earth => '현실과 안정 — 차근차근 쌓고 지키는',
      Element.air => '생각과 소통 — 가볍게 잇고 나누는',
      Element.water => '감정과 공감 — 깊이 느끼고 품는',
    };

/// 개인 차트 + 오늘 하늘을 레벨에 맞춰 풀이 카드 목록으로.
List<AstroReading> astroReadings(
    AstroChart c, DateTime now, ExplainLevel level) {
  final sky = computeTodaySky(now);
  return [
    _sunReading(c, level),
    _moonReading(c, level),
    _risingReading(c, level),
    _elementReading(c, level),
    _transitReading(c, sky, level),
  ];
}

AstroReading _sunReading(AstroChart c, ExplainLevel level) {
  final s = c.sunSign;
  final body = <String>[];
  switch (level) {
    case ExplainLevel.general:
      body.add('타고난 성향의 중심은 「${s.name}」예요. ${s.persona}');
      body.add('오늘도 이 결을 믿고 편하게 나답게 지내면 잘 풀려요.');
      break;
    case ExplainLevel.wangchobo:
      body.add('${gloss('sunsign', level)} — 태어난 날 태양이 머문 자리로, '
          '가장 밑바탕이 되는 성격이에요.');
      body.add('당신은 「${s.name}(${s.eng})」. ${s.persona}');
      body.add('이 별자리의 원소는 「${elementKor(s.element)}」 — '
          '${_elementTrait(s.element)} 기운이에요.');
      break;
    case ExplainLevel.chobo:
      body.add('태양 별자리는 성격의 뼈대예요. 당신은 「${s.name}」, '
          '한마디로 \'${s.keyword}\'의 사람이에요.');
      body.add(s.persona);
      body.add('${elementKor(s.element)} 원소 · ${s.mode}형 — '
          '${_elementTrait(s.element)} 성질이 바탕에 깔려요.');
      break;
    case ExplainLevel.junggeup:
      body.add('태양 「${s.name}」 · ${elementKor(s.element)} ${s.mode} · '
          '지배성 ${s.ruler}.');
      body.add(s.persona);
      body.add('태양은 자아·생명력의 축 — 정체성과 \'무엇으로 빛나는가\'를 가리켜요.');
      break;
    case ExplainLevel.gogeup:
      body.add('☉ ${s.name}(${s.eng}) — ${elementKor(s.element)}·${s.mode}·'
          '지배성 ${s.ruler}. 극성 '
          '${s.element == Element.fire || s.element == Element.air ? '양(능동)' : '음(수용)'}.');
      body.add('자아·의지·핵심 목적의 지표. ${s.persona}');
      break;
  }
  return AstroReading(
    key: 'sun',
    title: '태양 별자리',
    glyph: '☉',
    summary: '${s.symbol} ${s.name} · ${elementKor(s.element)}',
    body: body,
  );
}

AstroReading _moonReading(AstroChart c, ExplainLevel level) {
  final s = c.moonSign;
  final body = <String>[];
  switch (level) {
    case ExplainLevel.general:
      body.add('속마음이 움직이는 결은 「${s.name}」예요. '
          '겉으론 안 보여도 감정은 이렇게 흘러요.');
      body.add('편안함을 느끼는 방식: ${s.persona}');
      break;
    case ExplainLevel.wangchobo:
      body.add('${gloss('moonsign', level)} — 태어날 때 달이 머문 자리로, '
          '겉이 아니라 \'속마음·감정\'을 뜻해요.');
      body.add('당신의 감정은 「${s.name}」 결로 움직여요. ${s.persona}');
      break;
    case ExplainLevel.chobo:
      body.add('달 별자리는 감정·본능의 자리예요. 당신은 「${s.name}」 — '
          '마음이 편해지는 방식이 여기 담겨요.');
      body.add(s.persona);
      break;
    case ExplainLevel.junggeup:
      body.add('달 「${s.name}」 · ${elementKor(s.element)} ${s.mode}. '
          '정서 반응·안전 욕구의 축.');
      body.add(s.persona);
      break;
    case ExplainLevel.gogeup:
      body.add('☾ ${s.name} — ${elementKor(s.element)}·${s.mode}·'
          '지배성 ${s.ruler}. 정서·무의식·모성 지표.');
      body.add(s.persona);
      break;
  }
  return AstroReading(
    key: 'moon',
    title: '달 별자리',
    glyph: '☾',
    summary: '${s.symbol} ${s.name} · ${elementKor(s.element)}',
    body: body,
    note: c.hasTime
        ? null
        : '태어난 시각을 넣으면 달 별자리가 더 정확해져요(달은 약 2~2.5일마다 자리를 옮겨요 — 지금은 정오 기준 근사).',
  );
}

AstroReading _risingReading(AstroChart c, ExplainLevel level) {
  final s = c.risingSign;
  if (s == null) {
    return AstroReading(
      key: 'rising',
      title: '상승궁',
      glyph: '↑',
      summary: '시각·지역 필요',
      body: const [
        '상승궁(어센던트)은 태어난 \'시각과 장소\'가 있어야 계산돼요. '
            '남에게 비치는 첫인상·겉모습을 뜻하는 자리예요.',
      ],
      note: '설정에서 태어난 시각과 출생 지역을 넣으면 상승궁이 나타나요.',
    );
  }
  final body = <String>[];
  switch (level) {
    case ExplainLevel.general:
      body.add('남에게 비치는 첫인상은 「${s.name}」 느낌이에요.');
      body.add('처음 만난 사람은 당신을 이렇게 봐요: ${s.persona}');
      break;
    case ExplainLevel.wangchobo:
      body.add('${gloss('ascendant', level)} — 태어난 시각·장소로 정해지고, '
          '남이 처음 받는 인상이에요.');
      body.add('당신의 겉모습·분위기는 「${s.name}」 색이에요. ${s.persona}');
      break;
    case ExplainLevel.chobo:
      body.add('상승궁은 세상에 나를 내미는 \'문\'이에요. 당신은 「${s.name}」 — '
          '첫인상과 태도에 이 색이 배어나요.');
      body.add(s.persona);
      break;
    case ExplainLevel.junggeup:
      body.add('상승 「${s.name}」 · ${elementKor(s.element)} ${s.mode}. '
          '1하우스 커스프 — 외면·접근 방식·신체 인상.');
      body.add(s.persona);
      break;
    case ExplainLevel.gogeup:
      body.add('ASC ${s.name} — ${elementKor(s.element)}·${s.mode}·'
          '차트 룰러 ${s.ruler}. 페르소나·초두 인상·생활 태도의 관문.');
      body.add('※ 평항성시·고정 황도경사 기반 근사(분 단위 출생시각에 민감).');
      break;
  }
  return AstroReading(
    key: 'rising',
    title: '상승궁',
    glyph: '↑',
    summary: '${s.symbol} ${s.name} · ${elementKor(s.element)}',
    body: body,
  );
}

AstroReading _elementReading(AstroChart c, ExplainLevel level) {
  final dom = c.dominantElement;
  final lack = c.lackingElement;
  final parts = <String>[];
  for (final e in Element.values) {
    final n = c.elementCount[e]!;
    if (n > 0) parts.add('${elementKor(e)} $n');
  }
  final body = <String>[];
  final domTrait = _elementTrait(dom);
  switch (level) {
    case ExplainLevel.general:
      body.add('당신 안에서 가장 강한 결은 「${elementKor(dom)}」 — $domTrait 성향이에요.');
      if (lack != null) {
        body.add('상대적으로 옅은 「${elementKor(lack)}」 결은 '
            '${_elementTrait(lack)} 쪽 — 의식해서 채우면 균형이 좋아져요.');
      }
      break;
    case ExplainLevel.wangchobo:
      body.add('${gloss('element', level)}는 별자리를 넷(불·흙·공기·물)으로 나눈 성질이에요.');
      body.add('당신은 「${elementKor(dom)}」이 가장 강해요 — $domTrait 사람이에요. '
          '(태양·달${c.rising != null ? '·상승' : ''} 기준: ${parts.join(' / ')})');
      if (lack != null) {
        body.add('「${elementKor(lack)}」은 비어 있어요 — 이 결을 가진 사람·활동과 어울리면 채워져요.');
      }
      break;
    case ExplainLevel.chobo:
      body.add('원소 균형: ${parts.join(' / ')}.');
      body.add('가장 강한 「${elementKor(dom)}」($domTrait)이 성향을 이끌어요.');
      if (lack != null) {
        body.add('부족한 「${elementKor(lack)}」은 약점이자 배울 지점 — 채우면 폭이 넓어져요.');
      }
      break;
    case ExplainLevel.junggeup:
      body.add('원소 분포 ${parts.join(' / ')} → 우세 ${elementKor(dom)}'
          '${lack != null ? ' · 결핍 ${elementKor(lack)}' : ''}.');
      body.add('우세 원소가 기질의 주조를 이루고, 결핍 원소는 보상적으로 끌리는 영역이에요.');
      break;
    case ExplainLevel.gogeup:
      body.add('원소 벡터 ${parts.join(' / ')}. 우세 ${elementKor(dom)} '
          '(${dom == Element.fire || dom == Element.air ? '양극' : '음극'}) 편중'
          '${lack != null ? ', ${elementKor(lack)} 공백' : ''}.');
      body.add('삼중(태양·달·상승) 표본이라 소표본 편향은 감안 — 전체 하우스 배치로 보정 필요.');
      break;
  }
  return AstroReading(
    key: 'element',
    title: '원소 균형',
    glyph: '△',
    summary: parts.join(' · '),
    body: body,
  );
}

AstroReading _transitReading(
    AstroChart c, TodaySky sky, ExplainLevel level) {
  final natal = c.sunSign;
  final tSun = sky.sunSign;
  final tMoon = sky.moonSign;
  final sameElem = natal.element == tSun.element;
  final opposite = ((c.sun - sky.sun).abs() % 12) == 6;
  final relation = sameElem
      ? '순풍'
      : opposite
          ? '마주봄'
          : '무난';
  final body = <String>[];
  final flowLine = sameElem
      ? '오늘 하늘의 태양이 내 별자리와 같은 「${elementKor(natal.element)}」 결이라, '
          '나답게 움직일수록 힘이 붙는 날이에요.'
      : opposite
          ? '오늘 태양이 내 별자리 반대편에 있어, 관계·균형을 살피기 좋은 날이에요. '
              '나와 다른 시선을 받아들이면 오히려 배워요.'
          : '오늘 태양은 내 별자리와 무난하게 지나가요. 평소 리듬을 지키면 무탈해요.';
  switch (level) {
    case ExplainLevel.general:
      body.add(flowLine);
      body.add('오늘 달은 「${tMoon.name}」 자리 — 마음은 ${tMoon.keyword} 쪽으로 기울어요. '
          '${_moonMood(tMoon)}');
      break;
    case ExplainLevel.wangchobo:
      body.add('${gloss('transit', level)} — 지금 하늘의 별들이 내 별자리에 주는 흐름이에요.');
      body.add(flowLine);
      body.add('오늘 달은 「${tMoon.name}」($relation은 태양 기준). '
          '감정이 ${tMoon.keyword} 쪽으로 움직여요 — ${_moonMood(tMoon)}');
      break;
    case ExplainLevel.chobo:
      body.add('오늘 태양 「${tSun.name}」 vs 내 태양 「${natal.name}」 → $relation.');
      body.add(flowLine);
      body.add('오늘 달 「${tMoon.name}」 — ${_moonMood(tMoon)}');
      break;
    case ExplainLevel.junggeup:
      body.add('트랜짓 태양 ${tSun.name}(${elementKor(tSun.element)}) '
          '↔ 네이탈 태양 ${natal.name} : $relation'
          '${opposite ? ' (대궁)' : sameElem ? ' (동원소 트라인)' : ''}.');
      body.add('트랜짓 달 ${tMoon.name} — 당일 정서 색. ${_moonMood(tMoon)}');
      break;
    case ExplainLevel.gogeup:
      body.add('T.☉ ${tSun.name} / N.☉ ${natal.name} → '
          '${opposite ? '오포지션(180°)' : sameElem ? '트라인(120°) 계열' : '비주요 각'}. '
          'T.☾ ${tMoon.name}.');
      body.add('일간 무드는 트랜짓 달, 주간 톤은 트랜짓 태양이 주도 — ${_moonMood(tMoon)}');
      break;
  }
  return AstroReading(
    key: 'transit',
    title: '오늘의 하늘',
    glyph: '✦',
    summary: '태양 ${tSun.symbol}${tSun.name} · 달 ${tMoon.symbol}${tMoon.name}',
    body: body,
  );
}

String _moonMood(SignInfo m) => switch (m.element) {
      Element.fire => '활기가 오르니 몸을 움직이거나 표현하기 좋아요.',
      Element.earth => '차분해지니 정리·실무·돈 관리에 잘 맞아요.',
      Element.air => '생각이 많아지니 대화·연락·아이디어에 잘 맞아요.',
      Element.water => '감성이 짙어지니 쉼·사람·마음 돌보기에 잘 맞아요.',
    };
