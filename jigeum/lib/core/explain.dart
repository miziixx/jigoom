/// 설명 레벨(버전) 시스템 — 같은 계산 결과를 눈높이에 맞춰 다른 깊이·말투로 보여준다.
///
/// 일반인은 전문용어 없이 생활 조언만, 왕초보·초보는 용어에 쉬운 뜻풀이를 붙이고,
/// 중급·고급은 명리·점성 근거(십신·합충·용신, 원소·지배성·트랜짓)를 그대로 노출한다.
/// 계산 로직(fortune.dart·saju.dart·astrology.dart)은 레벨과 무관하며, 이 파일과
/// 렌더러(fortune_text.dart)가 표현만 바꾼다.

/// 설명 레벨. 일반인 → 왕초보 → 초보 → 중급 → 고급 순으로 전문성이 올라간다.
enum ExplainLevel { general, wangchobo, chobo, junggeup, gogeup }

const explainLevelKor = ['일반인', '왕초보', '초보', '중급', '고급'];

const explainLevelDesc = [
  '전문용어 없이 오늘 무엇을 하면 좋은지',
  '용어를 처음 봐도 옆에 쉬운 뜻이 붙어요',
  '용어와 함께 왜 그런지 한 줄 이유까지',
  '십신·합충·신강까지 근거를 갖춰',
  '용신·조후·형충회합 근거를 그대로',
];

String explainLevelLabel(ExplainLevel l) => explainLevelKor[l.index];

/// 저장·복원용 문자열 키.
const _levelKeys = ['general', 'wangchobo', 'chobo', 'junggeup', 'gogeup'];

String explainLevelKey(ExplainLevel l) => _levelKeys[l.index];

ExplainLevel explainLevelFromKey(String? key) {
  final i = _levelKeys.indexOf(key ?? 'general');
  return ExplainLevel.values[i < 0 ? 0 : i];
}

// ------------------------------------------------------------------ 레벨 성격

/// 전문용어를 아예 쓰지 않는 순수 생활 레벨(일반인).
bool plainOnly(ExplainLevel l) => l == ExplainLevel.general;

/// 용어 옆에 뜻풀이를 인라인으로 붙이는 레벨(왕초보·초보).
bool glossInline(ExplainLevel l) =>
    l == ExplainLevel.wangchobo || l == ExplainLevel.chobo;

/// 규칙·근거 블록을 노출하는 레벨(중급·고급).
bool showsBasis(ExplainLevel l) =>
    l == ExplainLevel.junggeup || l == ExplainLevel.gogeup;

/// 전문가용 최상위 레벨(고급) — 조후·형충회합·용신까지.
bool isAdvanced(ExplainLevel l) => l == ExplainLevel.gogeup;

// ------------------------------------------------------------------ 용어 사전

/// 한 용어의 이름·한자·쉬운 뜻.
class Term {
  const Term(this.name, this.hanja, this.plain);
  final String name; // 관성
  final String hanja; // 官星
  final String plain; // 직장·규칙·책임의 기운
}

const _terms = <String, Term>{
  // 십신 5그룹
  'bigyeop': Term('비겁', '比劫', '나와 같은 편·동료·경쟁의 기운'),
  'siksang': Term('식상', '食傷', '표현·재능·만들어내는 기운'),
  'jaeseong': Term('재성', '財星', '돈·현실 성과의 기운'),
  'gwanseong': Term('관성', '官星', '직장·규칙·책임의 기운'),
  'inseong': Term('인성', '印星', '배움·문서·나를 돌봐주는 기운'),
  // 관계
  'hap': Term('합', '合', '두 기운이 손잡아 매듭이 풀리는 것'),
  'chung': Term('충', '沖', '두 기운이 정면으로 부딪혀 흔들리는 것'),
  'hyeong': Term('형', '刑', '서로 갈고 다듬으며 마찰하는 것'),
  'wonjin': Term('원진', '怨嗔', '까닭 없이 껄끄러운 기운'),
  // 오행
  'mok': Term('목', '木', '자라나고 뻗는 나무의 기운'),
  'hwa': Term('화', '火', '타오르고 표현하는 불의 기운'),
  'to': Term('토', '土', '가운데서 받쳐주는 흙의 기운'),
  'geum': Term('금', '金', '단단히 매듭짓는 쇠의 기운'),
  'su': Term('수', '水', '스며들고 지혜로운 물의 기운'),
  // 강약·용신
  'singang': Term('신강', '身强', '내 힘이 넉넉한 상태'),
  'sinyak': Term('신약', '身弱', '도움을 받아 크는 상태'),
  'yongsin': Term('용신', '用神', '나에게 가장 이로운 기운'),
  'gisin': Term('기신', '忌神', '나에게 부담이 되는 기운'),
  'ilgan': Term('일간', '日干', '사주에서 나를 상징하는 글자'),
  'iljin': Term('일진', '日辰', '오늘 하루의 간지(하늘·땅 글자)'),
  // 점성
  'element': Term('원소', '元素', '별자리를 넷으로 나눈 성질(불·흙·공기·물)'),
  'ruler': Term('지배성', '支配星', '그 별자리를 이끄는 행성'),
  'ascendant': Term('상승궁', '上昇宮', '남에게 비치는 첫인상·겉모습'),
  'moonsign': Term('달 별자리', '月星座', '속마음·감정이 움직이는 결'),
  'sunsign': Term('태양 별자리', '太陽星座', '타고난 성향의 중심'),
  'transit': Term('트랜짓', '運行', '지금 하늘이 내 별자리에 주는 흐름'),
};

/// 용어를 레벨에 맞게 문자열화한다.
///
/// - 일반인: 쉬운 뜻만 ("직장·규칙·책임의 기운")
/// - 왕초보: 이름(한자, 쉬운 뜻) ("관성(官星, 직장·규칙·책임의 기운)")
/// - 초보: 이름(쉬운 뜻) ("관성(직장·규칙·책임의 기운)")
/// - 중급: 이름만 ("관성")
/// - 고급: 이름(한자) ("관성(官星)")
String gloss(String termKey, ExplainLevel level) {
  final t = _terms[termKey];
  if (t == null) return termKey;
  switch (level) {
    case ExplainLevel.general:
      return t.plain;
    case ExplainLevel.wangchobo:
      return '${t.name}(${t.hanja}, ${t.plain})';
    case ExplainLevel.chobo:
      return '${t.name}(${t.plain})';
    case ExplainLevel.junggeup:
      return t.name;
    case ExplainLevel.gogeup:
      return '${t.name}(${t.hanja})';
  }
}

/// 용어의 쉬운 뜻만.
String plainOf(String termKey) => _terms[termKey]?.plain ?? termKey;

/// 용어의 이름만.
String nameOf(String termKey) => _terms[termKey]?.name ?? termKey;
