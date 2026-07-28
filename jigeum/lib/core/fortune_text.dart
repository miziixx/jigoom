import 'explain.dart';
import 'fortune.dart';
import 'saju.dart';

/// 사주 운세 풀이 렌더러 — 카테고리 점수·신호(FortuneSignals)를 설명 레벨에 맞춰
/// 사람이 읽을 텍스트로 바꾼다. 계산은 fortune.dart, 표현(눈높이)은 여기서.
///
/// 원칙: 일반인은 전문용어 0으로 길고 자상하게, 왕초보·초보는 용어 옆에 쉬운 뜻을,
/// 중급·고급은 십신·합충·용신 근거를 노출. 모든 레벨에서 애매어를 피하고 구체적으로.

class CategoryText {
  const CategoryText({
    required this.summary,
    required this.body,
    required this.advice,
    this.basis = const [],
  });
  final String summary; // 한 줄 요약
  final List<String> body; // 본문 문단
  final String advice; // 실천 조언
  final List<String> basis; // 근거(중급·고급 전용)
}

String _groupKey(TenGodGroup g) =>
    const ['bigyeop', 'siksang', 'jaeseong', 'gwanseong', 'inseong'][g.index];

String _band(int s, String hi, String mid, String lo) =>
    s >= 70 ? hi : (s >= 50 ? mid : lo);

String _wx(int wx, ExplainLevel level) =>
    gloss(const ['mok', 'hwa', 'to', 'geum', 'su'][wx], level);

/// 카테고리 풀이 생성. 화면(_CategoryCard)이 이걸 그린다.
CategoryText describeCategory(FortuneCategory cat, ExplainLevel level) {
  final s = cat.sig;
  final score = cat.score;
  switch (cat.key) {
    case 'overall':
      return _overall(score, s, level);
    case 'career':
      return _career(score, s, level);
    case 'wealth':
      return _wealth(score, s, level);
    case 'relationship':
      return _relationship(score, s, level);
    case 'love':
      return _love(score, s, level);
    case 'documents':
      return _documents(score, s, level);
    case 'helpers':
      return _helpers(score, s, level);
    case 'study':
      return _study(score, s, level);
    case 'travel':
      return _travel(score, s, level);
    case 'disputes':
      return _disputes(score, s, level);
    case 'body':
      return _body(score, s, level);
    case 'mind':
      return _mind(score, s, level);
    case 'lucky':
      return _lucky(score, s, level);
    case 'earth':
      return _earth(score, s, level);
    default:
      return const CategoryText(summary: '', body: [], advice: '');
  }
}

// 오늘 기운(십신 그룹)을 도메인 맥락으로 풀어주는 쉬운 한 줄.
String _groupPlain(TenGodGroup g) {
  switch (g) {
    case TenGodGroup.bigyeop:
      return '오늘은 동료·경쟁·나 자신에 힘이 실리는 날이에요';
    case TenGodGroup.siksang:
      return '오늘은 표현하고 만들어내는 기운이 도는 날이에요';
    case TenGodGroup.jaeseong:
      return '오늘은 돈·현실 성과에 초점이 맞는 날이에요';
    case TenGodGroup.gwanseong:
      return '오늘은 책임·규칙·평가가 화두인 날이에요';
    case TenGodGroup.inseong:
      return '오늘은 배우고 정비하고 기대는 기운이 도는 날이에요';
  }
}

// 합·충 상태를 도메인 맞춤 문장으로(레벨별 용어 처리).
String? _hapChungLine(FortuneSignals s, ExplainLevel level,
    {required String hapMsg, required String chungMsg}) {
  if (s.hap > 0) {
    final tag = plainOnly(level) ? '' : '${gloss('hap', level)} — ';
    return '$tag$hapMsg';
  }
  if (s.chung > 0) {
    final tag = plainOnly(level) ? '' : '${gloss('chung', level)} — ';
    return '$tag$chungMsg';
  }
  return null;
}

// 신강/신약을 레벨별로.
String _strengthLine(FortuneSignals s, ExplainLevel level, String strongMsg,
    String weakMsg) {
  if (plainOnly(level)) return s.strong ? strongMsg : weakMsg;
  final term = gloss(s.strong ? 'singang' : 'sinyak', level);
  return '$term(${s.strengthPct}%) — ${s.strong ? strongMsg : weakMsg}';
}

// 근거 블록(중급·고급): 십신·합충·신강 사슬.
List<String> _basis(FortuneSignals s, ExplainLevel level,
    {String extra = ''}) {
  if (!showsBasis(level)) return const [];
  final g = gloss(_groupKey(s.group), level);
  final rel = s.hap > 0
      ? '지지 ${gloss('hap', level)} ${s.hap}'
      : s.chung > 0
          ? '지지 ${gloss('chung', level)} ${s.chung}'
          : '합충 없음';
  final strength = gloss(s.strong ? 'singang' : 'sinyak', level);
  final base =
      '오늘 기운 $g · $rel · $strength(${s.strengthPct}%) · 일진 ${s.todayHanja}';
  final adv = isAdvanced(level)
      ? '용신 ${gloss('yongsin', level)}=${_wx(s.yongsinWx, level)}, '
          '약한 오행 ${_wx(s.weakestWx, level)}·강한 오행 ${_wx(s.dominantWx, level)}'
      : '';
  return [base, if (extra.isNotEmpty) extra, if (adv.isNotEmpty) adv];
}

// ------------------------------------------------------------------ 총운
CategoryText _overall(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = score >= 85
      ? '흐름이 활짝 열린 하루'
      : score >= 70
          ? '순풍이 부는 하루'
          : score >= 55
              ? '무난히 흘러가는 하루'
              : score >= 40
                  ? '차분히 지켜갈 하루'
                  : '몸을 낮출 하루';

  if (plainOnly(level)) {
    body.add('${_groupPlain(s.group)}. 오늘 점수는 100점 만점에 '
        '$score점이에요.');
    body.add(s.strong
        ? '지금은 스스로 밀고 나갈 힘이 있는 흐름이라, 하고 싶은 일을 조금 더 적극적으로 해도 좋아요.'
        : '지금은 무리해서 밀어붙이기보다, 도움을 받고 리듬을 지키는 편이 이득인 흐름이에요.');
  } else {
    final g = gloss(_groupKey(s.group), level);
    body.add('오늘 하늘의 기운은 나(${gloss('ilgan', level)})에게 「$g」(으)로 작용해요. '
        '${_groupPlain(s.group)}.');
    body.add(_strengthLine(
        s,
        level,
        '넘치는 기운을 잘 써서 성과로 바꾸기 좋은 흐름이에요.',
        '기운을 아끼며 도움을 받아 크는 흐름이라, 무리보다 균형이 이득이에요.'));
  }

  final hc = _hapChungLine(s, level,
      hapMsg: '오늘 지지가 내 사주와 손을 잡아, 얽혔던 매듭이 부드럽게 풀리는 날이에요.',
      chungMsg: '오늘 지지가 내 사주와 부딪혀 예정된 흐름이 흔들릴 수 있어요. 큰 결정은 반나절만 미뤄도 좋아요.');
  if (hc != null) body.add(hc);
  if (s.hap == 0 && s.chung == 0) {
    body.add('오늘은 내 사주와 큰 충돌 없이 무난하게 지나가요.');
  }
  if (s.helpsWeak) {
    body.add(plainOnly(level)
        ? '평소 부족했던 기운이 오늘 채워져 균형이 잡히는 날이에요.'
        : '평소 약했던 ${_wx(s.weakestWx, level)} 기운이 채워지는 날 — 부족함이 메워지며 균형이 잡혀요.');
  }

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '기운이 좋을 때 미뤄둔 일을 앞당기세요. 먼저 움직이는 쪽이 이득이에요.'
        : score >= 55
            ? '평소의 리듬을 지키는 것이 오늘의 최선이에요.'
            : '오늘은 새로 벌이기보다 지키고 정비하는 날로 삼으세요.',
    basis: _basis(s, level),
  );
}

// ------------------------------------------------------------------ 직장·일
CategoryText _career(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = _band(score, '인정받는 하루', '무난한 근무', '몸을 낮출 때');

  if (showsBasis(level)) {
    body.add(switch (s.group) {
      TenGodGroup.gwanseong =>
        '${gloss('gwanseong', level)} 정면 — 직책·평가·규율이 화두. '
            '${s.strong ? '감당할 힘이 있어 인정·승진의 물꼬가 트여요.' : '신약이라 관살 부담 — 완벽보다 완수에 무게를.'}',
      TenGodGroup.jaeseong => '${gloss('jaeseong', level)} — 실무 성과·보상이 초점. 매듭짓는 만큼 평판.',
      TenGodGroup.inseong => '${gloss('inseong', level)} — 문서·자격·기반 다지기. 새 일 벌이기보다 정비.',
      TenGodGroup.siksang => '${gloss('siksang', level)} — 기획·발표·제안엔 힘, 규율과는 마찰 가능.',
      TenGodGroup.bigyeop => '${gloss('bigyeop', level)} — 협업엔 좋으나 공(功)은 나뉠 수 있음.',
    });
  } else {
    switch (s.group) {
      case TenGodGroup.gwanseong:
        body.add('오늘은 직장·규칙·책임의 기운이 정면으로 들어오는 날이에요. '
            '${plainOnly(level) ? '' : '(${gloss('gwanseong', level)}) '}'
            '평가받고 책임지는 일이 화두가 돼요.');
        body.add(s.strong
            ? '지금은 그 무게를 감당할 힘이 있어요. 먼저 나서서 보고하고 성과를 드러내면 인정으로 이어져요.'
            : '다만 지금은 짐이 무겁게 느껴질 수 있어요. 완벽하게 하려 애쓰기보다 \'끝까지 마치는 것\'에 무게를 두세요.');
        break;
      case TenGodGroup.jaeseong:
        body.add('오늘은 눈앞의 실무와 성과, 보상에 초점이 맞는 날이에요. '
            '작은 일이라도 확실히 매듭지으면 그만큼 평판으로 돌아와요.');
        break;
      case TenGodGroup.inseong:
        body.add('오늘은 배우고 정비하기 좋은 기운이에요. 새 일을 크게 벌이기보다 '
            '서류·자격·기반을 차분히 다지는 데 쓰면 알차요.');
        break;
      case TenGodGroup.siksang:
        body.add('오늘은 아이디어와 표현이 앞서는 날이에요. 기획·발표·제안에는 힘이 실리지만, '
            '딱딱한 규율과는 살짝 부딪힐 수 있으니 말투를 부드럽게 해 두세요.');
        break;
      case TenGodGroup.bigyeop:
        body.add('오늘은 동료·경쟁자와 나란히 서는 기운이에요. 함께 하는 일에는 좋지만, '
            '결과의 공(功)은 나눠야 할 수도 있어요.');
        break;
    }
  }

  final hc = _hapChungLine(s, level,
      hapMsg: '윗선·거래처와 뜻이 맞아떨어져요. 보고·요청은 오늘 하는 게 유리해요.',
      chungMsg: '상사·조직과 마찰선이 그어져 있어요. 감정보다 사실로 대응하면 손해가 줄어요.');
  if (hc != null) body.add(hc);

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '먼저 나서서 보고하고 성과를 드러내세요.'
        : score >= 55
            ? '맡은 선까지만 확실히 — 확장은 다음으로 미루세요.'
            : '오늘은 튀지 말고, 기록을 남기며 방어하는 날로.',
    basis: _basis(s, level,
        extra: showsBasis(level) && s.chung > 0 ? '일지·관성 충 → 조직 마찰선' : ''),
  );
}

// ------------------------------------------------------------------ 재물
CategoryText _wealth(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = _band(score, '재물의 문이 열림', '수입·지출 균형', '지갑을 지킬 때');

  if (showsBasis(level)) {
    body.add(switch (s.group) {
      TenGodGroup.jaeseong => '${gloss('jaeseong', level)} 도달 — 돈·계약의 통로. '
          '${s.strong ? '재를 감당 → 적극적 재물활동 유리.' : '신약 → 재다신약 경계, 큰 지출·투자 보류.'}',
      TenGodGroup.siksang => '식상생재(食傷生財) — 손으로 만든 결과가 수익으로. 부업·창작·영업 유리.',
      TenGodGroup.bigyeop => '${gloss('bigyeop', level)} — 비겁=재물 분탈. 지출·대여·공동정산 주의.',
      TenGodGroup.gwanseong => '${gloss('gwanseong', level)} — 이익보다 신용. 명예·직위가 앞섬.',
      TenGodGroup.inseong => '${gloss('inseong', level)} — 조건·계약서 검토기. 서두른 거래는 손해.',
    });
  } else {
    switch (s.group) {
      case TenGodGroup.jaeseong:
        body.add('오늘은 돈과 성과의 통로가 열리는 날이에요. '
            '${plainOnly(level) ? '' : '(${gloss('jaeseong', level)}) '}');
        body.add(s.strong
            ? '지금은 재물을 감당할 힘이 있어, 벌이와 계약에 적극적으로 나설 만해요.'
            : '다만 들어오는 만큼 나갈 수 있는 흐름이라, 큰 지출이나 투자는 며칠 미루는 게 안전해요.');
        break;
      case TenGodGroup.siksang:
        body.add('오늘은 내가 손을 움직여 만든 것이 수익으로 이어지는 날이에요. '
            '부업·창작·영업처럼 직접 만들고 파는 일에 특히 유리해요.');
        break;
      case TenGodGroup.bigyeop:
        body.add('오늘은 재물이 여럿으로 나뉘기 쉬운 기운이에요. 지출·빌려주기·공동 정산에 주의하고, '
            '내 몫을 분명히 하는 게 이득이에요.');
        break;
      case TenGodGroup.gwanseong:
        body.add('오늘은 당장의 이익보다 명예·직위·신용이 앞서는 날이에요. '
            '지금 신용을 쌓는 선택이 길게 남아요.');
        break;
      case TenGodGroup.inseong:
        body.add('오늘은 큰돈을 굴리기보다 정보·계약서·조건을 꼼꼼히 챙길 때예요. '
            '서두른 거래는 손해로 남기 쉬워요.');
        break;
    }
    body.add(s.strong
        ? '전체적으로 지금은 재물을 적극적으로 다뤄도 괜찮은 흐름이에요.'
        : '전체적으로 지금은 버는 쪽보다 지키는 쪽이 더 버는 흐름이에요.');
  }

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '미뤘던 계약·청구가 있다면 오늘 진행하세요.'
        : score >= 55
            ? '예산 안에서만 — 충동구매는 하루 미루기.'
            : '오늘은 새 지출·투자·보증을 피하세요.',
    basis: _basis(s, level),
  );
}

// ------------------------------------------------------------------ 인간관계
CategoryText _relationship(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = _band(score, '인연이 무르익음', '평온한 사이', '말을 아낄 때');

  if (showsBasis(level)) {
    body.add(switch (s.group) {
      TenGodGroup.bigyeop => '${gloss('bigyeop', level)} — 동료·인맥 활성. 협력에서 힘.',
      TenGodGroup.siksang => '${gloss('siksang', level)} — 사교·표현 매끄러움. 모임·발표 유리.',
      TenGodGroup.jaeseong => '${gloss('jaeseong', level)} — 실리로 맺는 거래적 인연.',
      TenGodGroup.gwanseong => '${gloss('gwanseong', level)} — 공적·상하 관계 중심. 예의가 곧 신뢰.',
      TenGodGroup.inseong => '${gloss('inseong', level)} — 윗사람·조력자와의 연이 도타워짐.',
    });
  } else {
    body.add(switch (s.group) {
      TenGodGroup.bigyeop =>
        '오늘은 사람들과 어깨를 나란히 하는 기운이에요. 오랜 친구·동료와의 연결이 살아나고, 함께할 때 힘이 나요.',
      TenGodGroup.siksang =>
        '오늘은 말과 표현이 매끄러운 날이에요. 첫인상이 좋고 대화가 잘 풀리니, 모임이나 발표에 유리해요.',
      TenGodGroup.jaeseong =>
        '오늘은 도움을 주고받는 실리적인 인연이 늘어나는 날이에요. 먼저 베풀면 그만큼 돌아와요.',
      TenGodGroup.gwanseong =>
        '오늘은 윗사람·공적인 관계가 중심이 되는 날이에요. 예의와 선을 지키면 신뢰가, 넘으면 마찰이 생겨요.',
      TenGodGroup.inseong =>
        '오늘은 나를 아껴주는 사람, 배울 만한 어른과의 인연이 도타워지는 날이에요. 조언을 구하기 좋아요.',
    });
  }

  final hc = _hapChungLine(s, level,
      hapMsg: '오해가 풀리고 화합의 자리가 만들어져요. 먼저 손 내밀기 좋은 날이에요.',
      chungMsg: '말이 날카로워지기 쉬운 날이에요. 한 박자만 늦춰 답하면 다툼을 피할 수 있어요.');
  if (hc != null) body.add(hc);

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '먼저 연락하고 자리를 만들어 보세요.'
        : score >= 55
            ? '오늘은 들어주는 역할이 이득이에요.'
            : '민감한 대화·단톡 논쟁은 내일로 미루세요.',
    basis: _basis(s, level),
  );
}

// ------------------------------------------------------------------ 애정·궁합
CategoryText _love(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = _band(score, '마음이 통함', '잔잔한 온기', '거리를 둘 때');

  if (s.spouseHap) {
    body.add(plainOnly(level)
        ? '오늘은 가까운 사람과 마음이 포개지는 날이에요. 새 인연이라면 신호가 통해요.'
        : '오늘 지지가 내 ${gloss('ilgan', level)}의 짝 자리(일지·배우자궁)와 ${gloss('hap', level)}을 이뤄요. '
            '가까운 사람과 마음이 포개지고, 새 인연이라면 신호가 통하는 날이에요.');
  } else if (s.spouseChung) {
    body.add(plainOnly(level)
        ? '오늘은 사소한 일로 각을 세우기 쉬운 날이에요. 오늘만큼은 지는 쪽이 이기는 쪽이에요.'
        : '오늘 지지가 배우자궁을 ${gloss('chung', level)}해요. 사소한 일로 부딪히기 쉬우니, '
            '오늘만큼은 지는 쪽이 이기는 쪽이에요.');
  } else {
    body.add(switch (s.group) {
      TenGodGroup.jaeseong || TenGodGroup.gwanseong =>
        '오늘은 설렘과 끌림이 오가는 날이에요. 마음이 가면 표현을 아끼지 마세요.',
      TenGodGroup.siksang => '오늘은 웃음과 여유가 사람을 끌어당기는 날이에요. 매력이 자연스럽게 배어나요.',
      _ => '오늘은 잔잔한 하루예요. 이벤트보다 익숙한 온기를 확인하기 좋은 날이에요.',
    });
  }
  body.add(s.hasHour
      ? (plainOnly(level)
          ? '태어난 시각까지 반영돼 인연의 결이 비교적 또렷하게 읽혀요.'
          : '태어난 시(時)까지 반영된 원국이라 애정·궁합의 결이 또렷해요.')
      : '설정에서 태어난 시각을 넣으면 애정·궁합 해석이 더 정밀해져요.');

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '망설였던 표현·연락을 오늘 건네보세요.'
        : score >= 55
            ? '큰 기대보다 작은 다정함으로.'
            : '예민한 대화는 피하고 혼자만의 시간을 가지세요.',
    basis: _basis(s, level,
        extra: showsBasis(level)
            ? (s.spouseHap
                ? '일지 합 → 배우자궁 인연'
                : s.spouseChung
                    ? '일지 충 → 배우자궁 갈등'
                    : '재·관=이성운 지표')
            : ''),
  );
}

// ------------------------------------------------------------------ 문서·계약
CategoryText _documents(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = _band(score, '도장 찍기 좋은 날', '검토엔 무난', '서명은 미룰 때');
  final inseong = s.group == TenGodGroup.inseong;
  final jeonggwan = s.group == TenGodGroup.gwanseong;

  if (plainOnly(level)) {
    body.add(inseong
        ? '오늘은 서류·자격·공부처럼 \'문서\'와 관련된 일이 잘 풀리는 날이에요. '
            '계약서, 지원서, 자격 준비에 좋은 기운이에요.'
        : jeonggwan
            ? '오늘은 공적인 문서·계약이 힘을 받는 날이에요. 관공서 일, 공식 서류에 유리해요.'
            : '오늘은 문서 일이 특별히 좋지도 나쁘지도 않은 무난한 흐름이에요. 급하지 않다면 서두를 필요는 없어요.');
  } else {
    body.add(inseong
        ? '${gloss('inseong', level)}이 도달하는 날 — 문서·자격·계약이 나에게 순하게 붙어요. '
            '지원서, 계약서, 자격 준비에 최적이에요.'
        : jeonggwan
            ? '${gloss('gwanseong', level)}의 날 — 공적 문서·계약이 힘을 받아요. 관공서·공식 절차에 유리해요.'
            : '오늘은 문서운이 뚜렷하지 않은 무난한 흐름이에요. 큰 서명은 문서에 유리한 날로 미뤄도 좋아요.');
  }

  final hc = _hapChungLine(s, level,
      hapMsg: '조건이 맞아떨어져요. 미뤄둔 서명·제출은 오늘이 유리해요.',
      chungMsg: '문구가 어긋나거나 조건이 흔들릴 수 있어요. 도장 찍기 전 한 번 더 읽으세요.');
  if (hc != null) body.add(hc);

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '검토를 마친 서류라면 오늘 제출·서명하세요.'
        : score >= 55
            ? '읽어만 두고, 서명은 조건을 한 번 더 확인한 뒤에.'
            : '오늘은 중요한 서명·제출을 미루고 초안만 다듬으세요.',
    basis: _basis(s, level,
        extra: showsBasis(level) ? '문서운 지표=인성·정관' : ''),
  );
}

// ------------------------------------------------------------------ 귀인·도움
CategoryText _helpers(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = _band(score, '귀인이 손 내미는 날', '도움은 잔잔히', '스스로 챙길 때');

  if (s.todayIsNoble) {
    body.add(plainOnly(level)
        ? '오늘은 나를 돕는 귀한 사람이 나타나기 쉬운 날이에요. 어려운 일은 혼자 끙끙대지 말고 청해 보세요.'
        : '오늘 지지가 내 ${gloss('ilgan', level)}의 천을귀인(天乙貴人) 자리예요 — '
            '전통적으로 위기에 도움을 주는 귀인이 붙는 날이에요. 도움을 청하기 좋아요.');
  } else if (s.group == TenGodGroup.inseong) {
    body.add(plainOnly(level)
        ? '오늘은 윗사람·선배의 도움이나 조언이 잘 닿는 날이에요. 배우거나 기대기 좋아요.'
        : '${gloss('inseong', level)}의 날 — 나를 돌봐주는 사람, 배울 어른의 손길이 닿기 쉬워요.');
  } else {
    body.add('오늘은 큰 도움이 뚜렷하진 않아요. 필요한 건 스스로 챙기되, '
        '${s.hap > 0 ? '마음 맞는 사람과의 연결은 살아 있어요.' : '먼저 다가가면 작은 도움은 얻을 수 있어요.'}');
  }
  if (s.hap > 0) {
    body.add(plainOnly(level)
        ? '사람과 사람이 이어지기 쉬운 날이라, 소개나 연결을 부탁하기 좋아요.'
        : '${gloss('hap', level)}의 기운이 있어 사람과 사람이 이어지기 쉬워요 — 소개·연결을 청하기 좋아요.');
  }

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '혼자 안고 있던 부탁이 있다면 오늘 꺼내 보세요.'
        : score >= 55
            ? '도움은 구체적으로 청할수록 잘 닿아요.'
            : '오늘은 스스로 해결하고, 기대는 다음으로.',
    basis: _basis(s, level,
        extra: showsBasis(level) && s.todayIsNoble ? '일진 지지=천을귀인' : ''),
  );
}

// ------------------------------------------------------------------ 학습·시험
CategoryText _study(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = _band(score, '몰입이 잘 됨', '꾸준함의 날', '입력보다 휴식');

  body.add(switch (s.group) {
    TenGodGroup.inseong => plainOnly(level)
        ? '오늘은 무언가를 배우고 받아들이는 힘이 가장 좋은 날이에요. 새 지식·자격·서류 공부에 딱이에요.'
        : '${gloss('inseong', level)}이 도달하는 날 — 흡수력이 가장 높아요. 새 지식·자격·문서 작업에 최적이에요.',
    TenGodGroup.siksang => plainOnly(level)
        ? '오늘은 직관과 창의가 살아나는 날이에요. 정리하고, 쓰고, 아이디어를 떠올리기 좋아요.'
        : '${gloss('siksang', level)}의 기운 — 직관·창의가 살아나요. 정리·집필·발상에 유리해요.',
    TenGodGroup.gwanseong => plainOnly(level)
        ? '오늘은 규칙적인 반복 학습, 시험·평가 준비에 힘이 실리는 날이에요.'
        : '${gloss('gwanseong', level)}의 날 — 규율 잡힌 반복 학습·시험 대비에 힘이 실려요.',
    TenGodGroup.jaeseong => '오늘은 바로 써먹을 실용 지식이 눈에 잘 들어오는 날이에요. 기술·재테크 공부가 잘 붙어요.',
    TenGodGroup.bigyeop => '오늘은 함께 배우면 능률이 오르는 날이에요. 혼자보다 스터디·토론이 나아요.',
  });
  body.add(s.helpsWeak
      ? (plainOnly(level)
          ? '평소 부족했던 기운이 채워져, 집중이 잘 붙는 날이에요.'
          : '${gloss('ilgan', level)}에게 필요한 ${_wx(s.weakestWx, level)} 기운을 오늘 하늘이 채워줘 집중이 잘 붙어요.')
      : '오늘은 새로 시작하기보다, 익힌 것을 복습·정리하면 더 오래 남아요.');

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '가장 어려운 과제를 오전에 배치하세요.'
        : score >= 55
            ? '분량을 정해 짧게 여러 번 나눠서.'
            : '새로 시작보다 복습·정리 위주로.',
    basis: _basis(s, level),
  );
}

// ------------------------------------------------------------------ 이동·여행
CategoryText _travel(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = _band(score, '길 위에서 트임', '가벼운 나들이', '집이 편할 때');

  if (s.todayIsYeokma) {
    body.add(plainOnly(level)
        ? '오늘은 움직임의 기운이 강한 날이에요. 출장·이동·나들이가 잘 풀리고, 밖에서 좋은 일이 생기기 쉬워요.'
        : '오늘 지지가 역마(驛馬)에 해당해요 — 이동·출장·여행의 기운이 강한 날이에요. 밖에서 기회가 열려요.');
  } else if (s.chung > 0) {
    body.add(plainOnly(level)
        ? '오늘은 자리가 들썩이는 기운이 있어요. 짧은 이동은 오히려 기분 전환이 되지만, 먼 길은 여유 있게 잡으세요.'
        : '${gloss('chung', level)}의 기운으로 자리가 들썩여요. 짧은 이동은 전환이 되지만, 먼 길은 시간 여유를 두세요.');
  } else {
    body.add('오늘은 이동운이 잔잔해요. 굳이 멀리 나서기보다 가까운 곳에서 볼일을 보면 알뜰해요.');
  }
  body.add(score >= 70
      ? '길 위에서 사람을 만나거나 아이디어가 트이기 좋은 날이에요.'
      : '무리한 일정보다 여유 있는 동선이 오늘의 안전이에요.');

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '미뤄둔 출장·나들이·약속을 오늘 잡아 보세요.'
        : score >= 55
            ? '가까운 이동 위주로, 짐은 가볍게.'
            : '먼 길·야간 운전은 피하고 여유 있게 움직이세요.',
    basis: _basis(s, level,
        extra: showsBasis(level) && s.todayIsYeokma ? '일진 지지=역마(寅申巳亥)' : ''),
  );
}

// ------------------------------------------------------------------ 구설·시비
CategoryText _disputes(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  // 높을수록 평온.
  final summary = _band(score, '입조심 걱정 없는 날', '말은 둥글게', '입을 아낄 때');

  if (score >= 70) {
    body.add('오늘은 말로 인한 다툼이나 구설 걱정이 적은 편안한 날이에요. 오해가 있었다면 풀기도 좋아요.');
  } else if (s.chung > 0) {
    body.add(plainOnly(level)
        ? '오늘은 말이 날카로워지고 시비가 붙기 쉬운 날이에요. 특히 예민한 주제는 오늘 꺼내지 마세요.'
        : '${gloss('chung', level)}의 기운으로 말이 날카로워지고 시비가 붙기 쉬워요. 예민한 주제는 오늘 피하세요.');
  } else if (s.group == TenGodGroup.siksang && !s.strong) {
    body.add(plainOnly(level)
        ? '오늘은 무심코 던진 말이 오해를 살 수 있는 날이에요. 특히 단톡·댓글에서 말수를 줄이면 좋아요.'
        : '${gloss('siksang', level)}이 강한데 힘이 받쳐주지 않아 말이 앞설 수 있어요 — 구설을 부르니 말수를 줄이세요.');
  } else {
    body.add('오늘은 큰 시비는 없지만, 감정 섞인 말 한마디는 조심하는 게 좋아요.');
  }
  if (s.hap > 0) {
    body.add('다행히 화해의 기운도 함께 있어, 먼저 부드럽게 다가가면 매듭이 풀려요.');
  }

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '오해가 있었다면 오늘 풀어보세요.'
        : score >= 55
            ? '중요한 말은 글보다 얼굴 보고, 한 박자 늦게.'
            : '오늘은 단톡·댓글·논쟁을 멀리하세요.',
    basis: _basis(s, level,
        extra: showsBasis(level) && s.chung > 0 ? '지지 충 → 구설·시비 유발' : ''),
  );
}

// ------------------------------------------------------------------ 건강·몸
CategoryText _body(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = _band(score, '컨디션 상승', '평이한 몸', '쉼이 필요');
  final organ = _organHint(s.todayBranchWx);

  body.add(switch (s.group) {
    TenGodGroup.gwanseong => s.strong
        ? '오늘은 긴장이 몸을 조이지만 버틸 힘은 있는 날이에요. 규칙적인 리듬이 컨디션을 지켜줘요.'
        : (plainOnly(level)
            ? '오늘은 스트레스와 피로가 크게 쌓이는 날이에요. 무리하면 배로 지치니 일정 사이에 쉼을 넣으세요.'
            : '${gloss('gwanseong', level)}의 소모가 큰 날 — 무리하면 피로가 배로 쌓여요. 쉼을 끼워 넣으세요.'),
    TenGodGroup.siksang => '오늘은 기운을 밖으로 쓰기 좋은 날이에요. 가벼운 운동·활동이 오히려 몸을 살려요.',
    TenGodGroup.inseong => '오늘은 몸을 재우고 채우는 기운이에요. 수면·영양·휴식의 효과가 큰 날이에요.',
    TenGodGroup.bigyeop => '오늘은 체력이 받쳐주는 날이에요. 미뤄둔 몸 쓰는 일을 해치우기 좋아요.',
    TenGodGroup.jaeseong => '오늘은 바깥 활동으로 에너지 소비가 큰 날이에요. 끼니와 수분을 놓치지 마세요.',
  });
  if (s.chung > 0) {
    body.add(plainOnly(level)
        ? '오늘은 삠·사고·과로에 약한 날이에요. $organ 쪽을 특히 조심하세요.'
        : '${gloss('chung', level)}의 날은 사고·삠·과로에 취약해요. $organ 쪽 무리를 특히 조심하세요.');
  } else {
    body.add('오늘 몸에서 살피면 좋은 곳은 $organ 이에요.');
  }

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '활동량을 늘려도 좋은 날 — 다만 마무리 스트레칭을 잊지 마세요.'
        : score >= 55
            ? '평소 리듬 유지 — 카페인·야식은 절제.'
            : '일찍 쉬고, 무리한 약속·운동은 줄이세요.',
    basis: _basis(s, level),
  );
}

// ------------------------------------------------------------------ 마음·정신
CategoryText _mind(int score, FortuneSignals s, ExplainLevel level) {
  final body = <String>[];
  final summary = _band(score, '평온·또렷함', '잔잔한 마음', '쉬어가는 마음');

  body.add(switch (s.group) {
    TenGodGroup.inseong => plainOnly(level)
        ? '오늘은 생각이 정돈되고 마음이 평온해지는 날이에요. 책·명상·정리가 잘 돼요.'
        : '${gloss('inseong', level)}이 마음을 감싸는 날 — 생각이 정돈되고 평온이 찾아와요. 독서·명상·정리가 잘 돼요.',
    TenGodGroup.siksang => '오늘은 속에 있는 것을 밖으로 꺼내면 후련해지는 날이에요. 표현하고 털어놓으세요.',
    TenGodGroup.gwanseong => plainOnly(level)
        ? '오늘은 \'해야 한다\'는 생각이 마음을 누르기 쉬운 날이에요. 할 일을 잘게 쪼개면 불안이 줄어요.'
        : '${gloss('gwanseong', level)}의 압박이 마음을 누르는 날 — 할 일을 잘게 쪼개면 불안이 줄어요.',
    TenGodGroup.jaeseong => '오늘은 현실 감각이 또렷해지는 날이에요. 걱정을 숫자·계획으로 적으면 막연함이 가라앉아요.',
    TenGodGroup.bigyeop => '오늘은 자기 확신이 서는 날이에요. 남과 비교하는 마음만 내려놓으면 단단해져요.',
  });
  final hc = _hapChungLine(s, level,
      hapMsg: '마음이 풀리는 기운이라, 미뤄둔 화해나 대화를 꺼내기 좋아요.',
      chungMsg: '감정 기복이 커요. 결정을 내리기 전 잠깐 멈추고 숨을 고르세요.');
  if (hc != null) body.add(hc);

  return CategoryText(
    summary: summary,
    body: body,
    advice: score >= 70
        ? '떠오른 생각을 글로 적어 방향을 정하세요.'
        : score >= 55
            ? '무리한 결심보다 작은 루틴 하나로.'
            : '오늘의 판단은 내일의 나에게 맡기세요.',
    basis: _basis(s, level),
  );
}

// ------------------------------------------------------------------ 행운 요소
CategoryText _lucky(int score, FortuneSignals s, ExplainLevel level) {
  final wx = s.yongsinWx; // 나에게 이로운 기운
  final dir = _luckyDir(wx);
  final color = _luckyColor(wx);
  final nums = _luckyNums(wx);
  final time = _luckyTime(wx);
  final body = <String>[];

  if (plainOnly(level)) {
    body.add('당신에게 가장 이로운 기운은 「${_wxPlain(wx)}」이에요. 이 기운을 채우면 하루가 부드러워져요.');
  } else {
    body.add('당신의 ${gloss('yongsin', level)}은 ${_wx(wx, level)} — '
        '이 기운을 채울수록 흐름이 트여요.');
  }
  body.add('오늘의 행운 방향은 「$dir쪽」, 행운 색은 「$color」이에요.');
  body.add('행운의 숫자는 「$nums」, 일이 잘 풀리는 시간대는 「$time」이에요.');
  if (score >= 70) {
    body.add('게다가 오늘 하늘의 기운이 당신에게 이로운 쪽이라, 위 요소들이 특히 잘 통하는 날이에요.');
  }

  return CategoryText(
    summary: '방향 $dir · 색 $color · 숫자 $nums',
    body: body,
    advice: '중요한 일은 「$time」에, 「$color」 소품을 지니고, 「$dir쪽」을 향해 앉아 보세요.',
    basis: showsBasis(level)
        ? ['${gloss('yongsin', level)}=${_wx(wx, level)} 기준 방위·색·수·시간 배정']
        : const [],
  );
}

// ------------------------------------------------------------------ 지구의 에너지
CategoryText _earth(int score, FortuneSignals s, ExplainLevel level) {
  final flow = s.earthFlow;
  final summary = flow == '상생(相生)'
      ? '하늘과 땅이 순하게 흐름'
      : flow == '상극(相剋)'
          ? '기운이 팽팽한 날'
          : '차분히 이어지는 날';
  final body = <String>[
    plainOnly(level)
        ? '오늘 하루의 결은 ${flow == '상생(相生)' ? '순하게 흐르는' : flow == '상극(相剋)' ? '팽팽하게 당겨지는' : '차분하게 이어지는'} 편이에요. 이건 나만이 아니라 모두에게 공통으로 깔리는 기운이에요.'
        : '오늘 일진은 ${s.todayHanja}(${s.todayKor}일). 하늘과 땅 글자가 $flow 관계라 하루의 결이 '
            '${flow == '상생(相生)' ? '순하게 흘러요.' : flow == '상극(相剋)' ? '팽팽하게 당겨져요.' : '차분하게 이어져요.'}',
    plainOnly(level)
        ? '오늘 땅에 깔린 기운은 「${_wxPlain(s.todayBranchWx)}」 — ${wuxingTrait[s.todayBranchWx]}의 결이에요.'
        : '땅의 오행은 ${_wx(s.todayBranchWx, level)} — ${wuxingTrait[s.todayBranchWx]}의 기운이 모두에게 공통으로 깔려요.',
    '오늘 하늘: 태양은 「${s.todaySunSign}」, 달은 「${s.todayMoonSign}」 자리에 머물러요.',
    if (s.solarTerm != null) '오늘은 절기 「${s.solarTerm}」 언저리 — 계절의 기운이 바뀌는 매듭이에요.',
  ];

  return CategoryText(
    summary: summary,
    body: body,
    advice: flow == '상생(相生)'
        ? '흐름에 올라타 새 일을 벌이기 좋은 날이에요.'
        : flow == '상극(相剋)'
            ? '거스르기보다 정비·점검에 하루를 쓰세요.'
            : '평소의 리듬을 지키면 무탈해요.',
    basis: showsBasis(level)
        ? ['일진 ${s.todayHanja} 천간·지지 $flow · 땅 오행 ${_wx(s.todayBranchWx, level)}']
        : const [],
  );
}

// ------------------------------------------------------------------ 헬퍼
String _wxPlain(int wx) => const ['목', '화', '토', '금', '수'][wx];

String _organHint(int wx) => switch (wx) {
      0 => '간·눈·근육',
      1 => '심장·혈압·소장',
      2 => '위장·소화',
      3 => '폐·기관지·피부',
      _ => '신장·방광·허리',
    };

String _luckyDir(int wx) =>
    const ['동', '남', '중앙', '서', '북'][wx];
String _luckyColor(int wx) =>
    const ['초록·청록', '빨강·분홍', '노랑·베이지', '흰색·은색', '검정·파랑'][wx];
String _luckyNums(int wx) =>
    const ['3·8', '2·7', '5·10', '4·9', '1·6'][wx];
String _luckyTime(int wx) => const [
      '아침(5~9시)',
      '한낮(11~13시)',
      '늦은 오후(13~15시)',
      '저녁(17~19시)',
      '밤(21~23시)',
    ][wx];
