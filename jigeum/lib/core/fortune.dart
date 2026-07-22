import 'almanac.dart';
import 'constants.dart';
import 'saju.dart';

/// 오늘의 운세 엔진 — 오프라인 규칙 기반.
///
/// 개인 사주 원국(SajuChart)과 오늘의 간지·절기·별자리를 십신(十神)·오행 상생상극·
/// 지지 합충 규칙으로 조합해 카테고리별 점수(0~100)와 풀이를 만든다. 결정적 함수이므로
/// 같은 사주·같은 날짜엔 항상 같은 결과가 나온다(재현성). 점수의 소폭 변동은 날짜·사주
/// 해시 기반 지터로만 준다 — 무작위가 아니다.

/// 한 카테고리의 운세 결과.
class FortuneCategory {
  const FortuneCategory({
    required this.key,
    required this.title,
    required this.glyph,
    required this.score,
    required this.summary,
    required this.lines,
    required this.advice,
  });

  final String key;
  final String title; // 직장
  final String glyph; // ⚑ 등 모노 기호
  final int score; // 0~100
  final List<String> lines; // 상세 풀이(문장)
  final String summary; // 한 줄 요약
  final String advice; // 실천 조언

  String get grade => gradeLabel(score);
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
  final Pillar todayPillar; // 오늘 일진 간지
  final String? solarTerm; // 오늘/직전 절기
  final int overall; // 총점 0~100
  final List<FortuneCategory> categories;

  String get overallGrade => gradeLabel(overall);

  /// 오늘 기운이 나(일간)에게 무슨 십신인가.
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

// ------------------------------------------------------------------ 계산
DailyFortune computeDailyFortune(SajuChart chart, DateTime today) {
  final d = dateOnly(today);
  final ti = dayGanziIndex(d);
  final todayPillar = Pillar(ti % 10, ti % 12);
  final term = solarTermName(d);

  final ctx = _Ctx(chart, d, todayPillar);

  final cats = <FortuneCategory>[
    _career(ctx),
    _wealth(ctx),
    _relationship(ctx),
    _love(ctx),
    _body(ctx),
    _mind(ctx),
    _study(ctx),
    _earth(ctx, term),
  ];

  // 총운 = 개인 8종 중 지구에너지 제외한 나머지의 가중 평균 + 균형 보정.
  final personal = cats.where((c) => c.key != 'earth').toList();
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
      _overall(ctx, overall),
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

    // 일간을 돕는(비겁·인성) 기운인지.
    supports = group == TenGodGroup.bigyeop || group == TenGodGroup.inseong;
    // 일지(배우자궁)와의 관계.
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

  /// 일간에게 이로운 정도(신강/신약 반영) — 카테고리 공통 베이스.
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

  /// 날짜·사주·카테고리 기반 결정적 지터(-4~+4).
  int jitter(String key) {
    final base = date.year * 10000 + date.month * 100 + date.day;
    final salt = chart.dayStem * 131 + chart.day.branch * 17 + key.hashCode;
    return ((base ^ salt).abs() % 9) - 4;
  }
}

int _clamp(int v) => v < 5 ? 5 : (v > 98 ? 98 : v);

// ------------------------------------------------------------------ 카테고리

FortuneCategory _overall(_Ctx x, int score) {
  final g = x.todayGroupLabel;
  final lines = <String>[
    '오늘의 기운은 나의 일간(${stemHanja[x.chart.dayStem]}·${wuxingKor[x.meWx]})에 '
        '$g(으)로 작용합니다. ${_groupHeadline(x.group, x.strong)}',
  ];
  if (x.hap > 0) {
    lines.add('오늘 지지(${branchHanja[x.today.branch]})가 내 사주와 '
        '${x.hap}곳에서 육합(六合)을 이뤄 매듭이 부드럽게 풀립니다.');
  } else if (x.chung > 0) {
    lines.add('오늘 지지가 내 사주와 ${x.chung}곳에서 충(沖)하니 예정된 흐름이 '
        '흔들릴 수 있어요. 큰 결정은 반나절 미뤄도 좋습니다.');
  } else {
    lines.add('오늘 지지는 내 원국과 큰 충돌 없이 무난하게 지나갑니다.');
  }
  if (x.helpsWeak) {
    lines.add('평소 약했던 ${wuxingKor[x.chart.weakestWuxing]}(${wuxingHanja[x.chart.weakestWuxing]}) '
        '기운이 채워지는 날 — 부족함이 메워지며 균형이 잡힙니다.');
  }
  return FortuneCategory(
    key: 'overall',
    title: '오늘의 총운',
    glyph: '◎',
    score: score,
    summary: _overallSummary(score),
    lines: lines,
    advice: _overallAdvice(score, x.group),
  );
}

FortuneCategory _career(_Ctx x) {
  var s = 55 + (x.favor * 6 ~/ 10);
  if (x.group == TenGodGroup.gwanseong) s += x.strong ? 16 : -6;
  if (x.group == TenGodGroup.inseong) s += 5;
  s += x.hap * 4 - x.chung * 7 + x.jitter('career');
  s = _clamp(s);

  final lines = <String>[
    switch (x.group) {
      TenGodGroup.gwanseong =>
        '관성(官)의 기운이 정면으로 들어오는 날 — 직책·평가·규율이 화두입니다. '
            '${x.strong ? '책임을 감당할 힘이 있어 인정·승진의 물꼬가 트입니다.' : '맡은 짐이 무겁게 느껴질 수 있으니 완벽보다 완수에 무게를 두세요.'}',
      TenGodGroup.jaeseong =>
        '재성의 기운이라 실무 성과와 보상이 초점입니다. 눈앞의 일을 매듭짓는 만큼 평판으로 돌아옵니다.',
      TenGodGroup.inseong =>
        '인성의 날 — 배우고 정비하는 기운입니다. 새 일을 벌이기보다 문서·자격·기반을 다지기 좋습니다.',
      TenGodGroup.siksang =>
        '식상의 기운으로 아이디어·표현이 앞섭니다. 기획·발표·제안엔 힘이 실리지만 규율과는 부딪힐 수 있어요.',
      TenGodGroup.bigyeop =>
        '비겁의 날 — 동료·경쟁자와 나란히 서는 기운입니다. 협업엔 좋으나 공(功)은 나눠야 할 수 있습니다.',
    },
  ];
  if (x.chung > 0) {
    lines.add('상사·조직과의 마찰선이 그어져 있어요. 감정보다 사실로 대응하면 손해가 줄어듭니다.');
  } else if (x.hap > 0) {
    lines.add('윗선·거래처와 뜻이 맞아떨어지는 흐름 — 보고·요청은 오늘 하는 게 유리합니다.');
  }
  return FortuneCategory(
    key: 'career',
    title: '직장·상사',
    glyph: '⚑',
    score: s,
    summary: _band(s, '인정받는 하루', '무난한 근무', '몸을 낮출 때'),
    lines: lines,
    advice: s >= 70
        ? '먼저 나서서 보고하고 성과를 드러내세요.'
        : s >= 55
            ? '맡은 선까지만 확실히 — 확장은 다음으로.'
            : '오늘은 튀지 말고 기록을 남기며 방어하세요.',
  );
}

FortuneCategory _wealth(_Ctx x) {
  var s = 55 + (x.favor * 5 ~/ 10);
  if (x.group == TenGodGroup.jaeseong) s += x.strong ? 15 : -2;
  if (x.group == TenGodGroup.siksang) s += 8; // 식상생재
  if (x.group == TenGodGroup.bigyeop) s += x.strong ? -4 : -10; // 비겁=재물분탈
  s += x.hap * 3 - x.chung * 5 + x.jitter('wealth');
  s = _clamp(s);

  final lines = <String>[
    switch (x.group) {
      TenGodGroup.jaeseong =>
        '재성이 도달하는 날 — 돈·성과의 통로가 열립니다. '
            '${x.strong ? '벌이와 계약에 적극적으로 나설 만합니다.' : '들어오는 만큼 나갈 수 있으니 큰 지출·투자는 미루세요.'}',
      TenGodGroup.siksang =>
        '식상이 재를 낳는(食傷生財) 흐름 — 손을 움직여 만든 결과가 수익으로 이어집니다. 부업·창작·영업에 유리합니다.',
      TenGodGroup.bigyeop =>
        '비겁의 날은 재물이 나뉘는 기운 — 지출·빌려주기·공동정산에 주의하세요. 내 몫을 분명히 하는 게 이득입니다.',
      TenGodGroup.gwanseong =>
        '관성의 기운이라 재물보다 명예·직위가 앞섭니다. 당장의 이익보다 신용을 쌓는 선택이 길게 남습니다.',
      TenGodGroup.inseong =>
        '인성의 날 — 큰돈보다 정보·계약서·조건을 꼼꼼히 챙길 때입니다. 서두른 거래는 손해로 남습니다.',
    },
  ];
  lines.add(x.strong
      ? '지금 사주는 재를 감당할 힘이 있어, 적극적인 재물 활동이 대체로 이롭습니다.'
      : '지금 사주는 힘을 아껴야 하는 흐름이라, 재물은 지키는 쪽이 버는 쪽보다 낫습니다.');
  return FortuneCategory(
    key: 'wealth',
    title: '직업·재물',
    glyph: '❖',
    score: s,
    summary: _band(s, '재물의 문이 열림', '수입 지출 균형', '지갑을 지킬 때'),
    lines: lines,
    advice: s >= 70
        ? '결정을 미뤘던 계약·청구가 있다면 오늘 진행하세요.'
        : s >= 55
            ? '예산 안에서만 — 충동구매는 하루 미루기.'
            : '오늘은 새 지출·투자·보증을 피하세요.',
  );
}

FortuneCategory _relationship(_Ctx x) {
  var s = 55;
  if (x.group == TenGodGroup.bigyeop) s += 12; // 비겁=동료·인맥
  if (x.group == TenGodGroup.siksang) s += 8; // 식상=사교·표현
  if (x.group == TenGodGroup.gwanseong) s += x.strong ? 4 : -6;
  s += x.hap * 6 - x.chung * 7 + x.jitter('relationship');
  s = _clamp(s);

  final lines = <String>[
    switch (x.group) {
      TenGodGroup.bigyeop =>
        '비겁의 날 — 사람들과 어깨를 나란히 하는 기운입니다. 오랜 친구·동료와의 연결이 살아나고, 협력에서 힘이 납니다.',
      TenGodGroup.siksang =>
        '식상의 기운으로 말과 표현이 매끄러운 날 — 첫인상이 좋고 대화가 잘 풀립니다. 모임·발표에 유리합니다.',
      TenGodGroup.jaeseong =>
        '재성의 날은 실리로 맺어지는 관계 — 도움을 주고받는 거래적 인연이 늘어납니다. 베푼 만큼 돌아옵니다.',
      TenGodGroup.gwanseong =>
        '관성의 기운이라 윗사람·공적 관계가 중심입니다. 예의와 선을 지키면 신뢰가, 넘으면 마찰이 생깁니다.',
      TenGodGroup.inseong =>
        '인성의 날 — 나를 아껴주는 사람, 배울 만한 어른과의 인연이 도타워집니다. 조언을 구하기 좋은 날입니다.',
    },
  ];
  if (x.hap > 0) {
    lines.add('오늘 지지가 내 사주와 합(合)하니 오해가 풀리고 화합의 자리가 만들어집니다.');
  } else if (x.chung > 0) {
    lines.add('충(沖)의 기운이 있어 말이 날카로워지기 쉬워요. 한 박자 늦춰 답하면 다툼을 피합니다.');
  }
  return FortuneCategory(
    key: 'relationship',
    title: '인간관계',
    glyph: '⚭',
    score: s,
    summary: _band(s, '인연이 무르익음', '평온한 사이', '말을 아낄 때'),
    lines: lines,
    advice: s >= 70
        ? '먼저 연락하고 자리를 만들어 보세요.'
        : s >= 55
            ? '들어주는 역할이 오늘의 이득입니다.'
            : '민감한 대화·단톡 논쟁은 내일로 미루세요.',
  );
}

FortuneCategory _love(_Ctx x) {
  var s = 55;
  if (x.spouseHap) s += 16; // 일지 합=배우자궁 인연
  if (x.spouseChung) s += -12; // 일지 충=배우자궁 갈등
  // 여자=관성, 남자=재성이 이성운. 성별 미상 → 둘 다 소폭 반영.
  if (x.group == TenGodGroup.jaeseong || x.group == TenGodGroup.gwanseong) {
    s += 8;
  }
  if (x.group == TenGodGroup.siksang) s += 5; // 매력·표현
  s += x.jitter('love');
  s = _clamp(s);

  final lines = <String>[
    if (x.spouseHap)
      '오늘 지지가 내 일지(日支·배우자궁 ${branchHanja[x.chart.day.branch]})와 합을 이룹니다. '
          '가까운 사람과의 마음이 포개지고, 새 인연이라면 신호가 통하는 날입니다.'
    else if (x.spouseChung)
      '오늘 지지가 배우자궁을 충(沖)합니다. 사소한 일로 각을 세우기 쉬우니, '
          '오늘만큼은 지는 쪽이 이기는 쪽입니다.'
    else
      switch (x.group) {
        TenGodGroup.jaeseong || TenGodGroup.gwanseong =>
          '이성의 기운(재·관)이 도는 날 — 설렘과 끌림이 오갑니다. 표현을 아끼지 마세요.',
        TenGodGroup.siksang =>
          '식상의 매력이 도는 날 — 웃음과 여유가 사람을 끌어당깁니다.',
        _ => '잔잔한 하루 — 이벤트보다 익숙한 온기를 확인하기 좋은 날입니다.',
      },
  ];
  lines.add(x.chart.hasHour
      ? '태어난 시(時)까지 반영된 원국이라 인연의 결이 비교적 또렷하게 읽힙니다.'
      : '태어난 시각을 넣으면 애정·궁합의 해석이 더 정밀해집니다.');
  return FortuneCategory(
    key: 'love',
    title: '애정·인연',
    glyph: '♡',
    score: s,
    summary: _band(s, '마음이 통함', '잔잔한 온기', '거리를 둘 때'),
    lines: lines,
    advice: s >= 70
        ? '망설였던 표현·연락을 오늘 건네보세요.'
        : s >= 55
            ? '큰 기대보다 작은 다정함으로.'
            : '예민한 대화는 피하고 혼자만의 시간을.',
  );
}

FortuneCategory _body(_Ctx x) {
  var s = 58;
  if (x.group == TenGodGroup.gwanseong && !x.strong) s -= 12; // 관살=압박·소모
  if (x.group == TenGodGroup.siksang && x.strong) s += 8; // 발산=활력
  if (x.supports) s += 6; // 비겁·인성=회복
  if (x.helpsWeak) s += 5;
  s += -x.chung * 8 + x.hap * 2 + x.jitter('body');
  s = _clamp(s);

  // 오늘 오행이 극하는 신체 영역 힌트.
  final organ = _organHint(x.todayBranchWx);
  final lines = <String>[
    switch (x.group) {
      TenGodGroup.gwanseong => x.strong
          ? '긴장이 몸을 조이지만 버틸 힘은 있는 날 — 규칙적인 리듬이 컨디션을 지킵니다.'
          : '관살(官殺)의 소모가 큰 날 — 무리하면 피로가 배로 쌓입니다. 일정 사이에 쉼을 넣으세요.',
      TenGodGroup.siksang => '기운을 밖으로 쓰기 좋은 날 — 가벼운 운동·활동이 오히려 몸을 살립니다.',
      TenGodGroup.inseong => '몸을 재우고 채우는 기운 — 수면·영양·휴식의 효과가 큰 날입니다.',
      TenGodGroup.bigyeop => '체력이 받쳐주는 날 — 미뤄둔 몸 쓰는 일을 해치우기 좋습니다.',
      TenGodGroup.jaeseong => '바깥 활동으로 에너지 소비가 큰 날 — 끼니와 수분을 놓치지 마세요.',
    },
  ];
  if (x.chung > 0) {
    lines.add('충(沖)의 날은 사고·삠·과로에 취약합니다. $organ 쪽 무리를 특히 조심하세요.');
  } else {
    lines.add('오늘 하늘의 오행은 ${wuxingKor[x.todayBranchWx]}(${wuxingHanja[x.todayBranchWx]}) — '
        '$organ 을(를) 살피면 좋습니다.');
  }
  return FortuneCategory(
    key: 'body',
    title: '몸 상태',
    glyph: '✚',
    score: s,
    summary: _band(s, '컨디션 상승', '평이한 몸', '쉼이 필요'),
    lines: lines,
    advice: s >= 70
        ? '활동량을 늘려도 좋은 날 — 다만 마무리 스트레칭을.'
        : s >= 55
            ? '평소 리듬 유지 — 카페인·야식은 절제.'
            : '일찍 쉬고, 무리한 약속·운동은 줄이세요.',
  );
}

FortuneCategory _mind(_Ctx x) {
  var s = 56;
  if (x.group == TenGodGroup.inseong) s += 12; // 인성=안정·수용
  if (x.group == TenGodGroup.siksang) s += x.strong ? 8 : 3; // 발산=해소
  if (x.group == TenGodGroup.gwanseong && !x.strong) s -= 9; // 압박=불안
  if (x.group == TenGodGroup.bigyeop) s += 4;
  s += x.hap * 3 - x.chung * 6 + x.jitter('mind');
  s = _clamp(s);

  final lines = <String>[
    switch (x.group) {
      TenGodGroup.inseong =>
        '인성이 마음을 감싸는 날 — 생각이 정돈되고 평온이 찾아옵니다. 독서·명상·정리가 잘 됩니다.',
      TenGodGroup.siksang =>
        '식상의 기운으로 안이 밖으로 나오는 날 — 표현하고 털어놓으면 체증이 내려갑니다.',
      TenGodGroup.gwanseong =>
        '관성의 압박이 마음을 누르는 날 — 해야 한다는 생각이 커집니다. 할 일을 잘게 쪼개면 불안이 줄어요.',
      TenGodGroup.jaeseong =>
        '현실 감각이 또렷해지는 날 — 계획을 숫자로 적으면 막연한 걱정이 가라앉습니다.',
      TenGodGroup.bigyeop =>
        '자기 확신이 서는 날 — 남과 비교하는 마음만 내려놓으면 단단해집니다.',
    },
  ];
  if (x.chung > 0) {
    lines.add('충의 기운으로 감정 기복이 큽니다. 결정을 내리기 전 잠깐 멈추고 숨을 고르세요.');
  } else if (x.hap > 0) {
    lines.add('합의 기운이 마음을 풀어줍니다 — 미뤄둔 화해나 대화를 꺼내기 좋습니다.');
  }
  return FortuneCategory(
    key: 'mind',
    title: '마음 상태',
    glyph: '❋',
    score: s,
    summary: _band(s, '평온·또렷함', '잔잔한 마음', '쉬어가는 마음'),
    lines: lines,
    advice: s >= 70
        ? '떠오른 생각을 글로 적어 방향을 정하세요.'
        : s >= 55
            ? '무리한 결심보다 작은 루틴 하나로.'
            : '오늘의 판단은 내일의 나에게 맡기세요.',
  );
}

FortuneCategory _study(_Ctx x) {
  var s = 55;
  if (x.group == TenGodGroup.inseong) s += 14; // 인성=학습·문서
  if (x.group == TenGodGroup.siksang) s += 6; // 식상=아이디어·창작
  if (x.helpsWeak) s += 5;
  s += x.hap * 2 - x.chung * 4 + x.jitter('study');
  s = _clamp(s);

  final lines = <String>[
    switch (x.group) {
      TenGodGroup.inseong =>
        '인성이 도달하는 날 — 배움의 흡수력이 가장 높습니다. 새 지식·자격·문서 작업에 최적입니다.',
      TenGodGroup.siksang =>
        '식상의 기운으로 직관과 창의가 살아납니다 — 정리·집필·아이디어 발상에 유리합니다.',
      TenGodGroup.gwanseong =>
        '관성의 날 — 규율 잡힌 반복 학습, 시험·평가 대비에 힘이 실립니다.',
      TenGodGroup.jaeseong =>
        '실용 지식이 눈에 들어오는 날 — 바로 써먹을 기술·재테크 공부가 잘 붙습니다.',
      TenGodGroup.bigyeop =>
        '함께 배우면 능률이 오르는 날 — 스터디·토론이 혼자보다 낫습니다.',
    },
  ];
  lines.add('일간 ${stemHanja[x.chart.dayStem]}에게 필요한 ${wuxingKor[x.chart.weakestWuxing]} 기운을 '
      '${x.helpsWeak ? '오늘 하늘이 채워줍니다 — 집중이 잘 붙는 날입니다.' : '의식적으로 채우면(관련 분야 학습) 흐름이 트입니다.'}');
  return FortuneCategory(
    key: 'study',
    title: '학습·직감',
    glyph: '✎',
    score: s,
    summary: _band(s, '몰입이 잘 됨', '꾸준함의 날', '입력보다 휴식'),
    lines: lines,
    advice: s >= 70
        ? '가장 어려운 과제를 오전에 배치하세요.'
        : s >= 55
            ? '분량을 정해 짧게 여러 번 나눠서.'
            : '새로 시작보다 복습·정리 위주로.',
  );
}

FortuneCategory _earth(_Ctx x, String? term) {
  // 개인 무관 — 오늘 하늘·땅의 공통 기운(오늘 일진 오행·절기·별자리·달).
  final sunSign = zodiacOf(x.date);
  final lunar = lunarShort(x.date);
  final todayWx = branchWuxing(x.today.branch);

  // 오늘 천간·지지 오행의 상생 흐름으로 '결'을 잡는다.
  final flow = (stemWuxing(x.today.stem) + 1) % 5 == branchWuxing(x.today.branch)
      ? '상생(相生)'
      : (stemWuxing(x.today.stem) + 2) % 5 == branchWuxing(x.today.branch)
          ? '상극(相剋)'
          : '나란함';
  var s = flow == '상생(相生)'
      ? 74
      : flow == '상극(相剋)'
          ? 48
          : 62;
  s = _clamp(s + x.jitter('earth'));

  final lines = <String>[
    '오늘 일진은 ${x.today.hanja}(${x.today.kor}일). '
        '천간과 지지가 $flow 관계라 하루의 결이 '
        '${flow == '상생(相生)' ? '순하게 흐릅니다.' : flow == '상극(相剋)' ? '팽팽하게 당겨집니다.' : '차분하게 이어집니다.'}',
    '땅의 오행은 ${wuxingKor[todayWx]}(${wuxingHanja[todayWx]}) — ${wuxingTrait[todayWx]}의 기운이 '
        '모두에게 공통으로 깔립니다.',
    '하늘: 태양은 ${sunSign.symbol} ${sunSign.name}(${sunSign.element})에 머물고, 달은 $lunar 무렵입니다.',
    if (term != null) '오늘은 절기 「$term」 언저리 — 계절의 기운이 바뀌는 매듭입니다.',
  ];
  return FortuneCategory(
    key: 'earth',
    title: '지구의 에너지',
    glyph: '☯',
    score: s,
    summary: flow == '상생(相生)'
        ? '하늘과 땅이 순하게 흐름'
        : flow == '상극(相剋)'
            ? '기운이 팽팽한 날'
            : '차분히 이어지는 날',
    lines: lines,
    advice: flow == '상생(相生)'
        ? '흐름에 올라타 새 일을 벌이기 좋은 날입니다.'
        : flow == '상극(相剋)'
            ? '거스르기보다 정비·점검에 하루를 쓰세요.'
            : '평소의 리듬을 지키면 무탈합니다.',
  );
}

// ------------------------------------------------------------------ 문구 헬퍼
String _band(int s, String hi, String mid, String lo) =>
    s >= 70 ? hi : (s >= 50 ? mid : lo);

String _groupHeadline(TenGodGroup g, bool strong) {
  switch (g) {
    case TenGodGroup.bigyeop:
      return strong ? '이미 강한 나에게 힘이 더해지니, 밀어붙이기보다 나누는 날.' : '든든한 지원군이 붙어 자신감이 붙는 날.';
    case TenGodGroup.inseong:
      return strong ? '채움이 넘칠 수 있으니 배운 것을 덜어내 쓰는 날.' : '기댈 언덕이 생겨 마음이 놓이는 날.';
    case TenGodGroup.siksang:
      return strong ? '안의 것을 밖으로 풀어내기 좋은, 표현과 성과의 날.' : '기운을 쓰는 만큼 나를 살피며 나아갈 날.';
    case TenGodGroup.jaeseong:
      return strong ? '거둬들이기 좋은, 현실 성과의 날.' : '욕심을 줄이면 실속이 남는 날.';
    case TenGodGroup.gwanseong:
      return strong ? '책임을 통해 인정으로 나아가는 날.' : '짐이 무거우니 완벽보다 완수에 무게를 둘 날.';
  }
}

String _overallSummary(int s) => s >= 85
    ? '흐름이 활짝 열린 하루'
    : s >= 70
        ? '순풍이 부는 하루'
        : s >= 55
            ? '무난히 흘러가는 하루'
            : s >= 40
                ? '차분히 지켜갈 하루'
                : '몸을 낮출 하루';

String _overallAdvice(int s, TenGodGroup g) => s >= 70
    ? '기운이 좋을 때 미뤄둔 일을 앞당기세요.'
    : s >= 55
        ? '평소의 리듬을 지키는 것이 최선입니다.'
        : '오늘은 벌이기보다 지키고 정비하는 날로.';

/// 지지 오행 → 살필 신체 영역(전통 오행-장부 대응, 가벼운 참고용).
String _organHint(int wx) => switch (wx) {
      0 => '간·눈·근육(木)',
      1 => '심장·혈압·소장(火)',
      2 => '위장·소화·비장(土)',
      3 => '폐·기관지·피부(金)',
      _ => '신장·방광·허리(水)',
    };

extension on _Ctx {
  String get todayGroupLabel => tenGodGroupKor[group.index];
}
