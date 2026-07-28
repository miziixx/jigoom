import type { BranchRelationKind, FortuneCategoryContent, FortuneContent, FortuneEvidence, TenGodGroup } from "../types/index.js";

/**
 * LLM 호출 실패 시 사용하는 룰 기반 폴백.
 * 근거 데이터만으로 완곡하고 안전한 문장(단정·공포·중대결정 유도 없음)을 조립한다.
 * 사주 전문용어(십성 이름·간지·합충 등)는 표면 문장에 노출하지 않고 쉬운 말로만 옮긴다.
 * LLM 결과와 형식(FortuneContent)이 동일하므로 UI는 출처를 구분할 필요가 없다.
 */

/** 십성 그룹을 쉬운 키워드 하나로 순화 */
const GROUP_KEYWORD: Record<TenGodGroup, string> = {
  비겁: "협력",
  식상: "표현",
  재성: "실속",
  관성: "집중",
  인성: "휴식",
};

const GROUP_DO: Record<TenGodGroup, string> = {
  비겁: "혼자 끌어안기보다 사람들과 역할을 나눠보기",
  식상: "미뤄둔 표현이나 결과물을 하나 밖으로 내보내기",
  재성: "숫자·마감처럼 손에 잡히는 실무 하나를 매듭짓기",
  관성: "해야 할 일의 우선순위와 규칙을 먼저 정리하기",
  인성: "정보를 모으고 배우는 데 시간을 조금 더 쓰기",
};

const RELATION_CAUTION: Partial<Record<BranchRelationKind, string>> = {
  충: "일정이나 계획이 갑자기 바뀌기 쉬운 흐름이라, 여유 시간을 두는 편이 좋아요",
  형: "작은 마찰이나 조정이 생기기 쉬우니 말과 절차를 한 번 더 확인해보세요",
  원진: "이유 없이 껄끄러운 감정이 올라올 수 있어 즉답을 미루는 게 편할 수 있어요",
  파: "엇갈림이 생기기 쉬운 날이라 약속·전달 사항을 다시 맞춰보면 좋아요",
  해: "은근히 거슬리는 일이 끼어들 수 있으니 페이스를 지키는 데 집중해보세요",
};

const RELATION_GOOD: Partial<Record<BranchRelationKind, string>> = {
  육합: "주변과 손발이 맞아 협력이 잘 풀리기 쉬운 흐름이에요",
  삼합: "여러 조건이 맞물려 일이 술술 이어지기 좋은 기운이에요",
  방합: "같은 방향을 보는 사람들과 힘을 모으기 좋은 날이에요",
};

const RELATION_KEYWORD_GOOD = "협력";
const RELATION_KEYWORD_CAUTION = "변화 주의";

function band(score: number): "high" | "mid" | "low" {
  if (score >= 62) return "high";
  if (score >= 45) return "mid";
  return "low";
}

/** 점수 구간에 맞는 문구 하나를 고른다 */
function pick(score: number, high: string, mid: string, low: string): string {
  const b = band(score);
  return b === "high" ? high : b === "mid" ? mid : low;
}

/** 오늘 근거에서 활성화된(관계가 있는) 지지 관계 종류를 자리 가중치 순으로 모은다 */
function activeRelations(evidence: FortuneEvidence): BranchRelationKind[] {
  const sorted = [...evidence.branchRelations].sort((a, b) => b.weight - a.weight);
  const seen = new Set<BranchRelationKind>();
  const out: BranchRelationKind[] = [];
  for (const r of sorted) {
    for (const k of r.relations) {
      if (!seen.has(k)) {
        seen.add(k);
        out.push(k);
      }
    }
  }
  return out;
}

export function buildFallbackFortune(evidence: FortuneEvidence): FortuneContent {
  const e = evidence;
  const c = e.categories;
  const rels = activeRelations(e);
  const goodRel = rels.find((r) => RELATION_GOOD[r]);
  const cautionRel = rels.find((r) => RELATION_CAUTION[r]);

  // 카테고리 점수 순위
  const entries: Array<[string, number]> = [
    ["재물", c.money],
    ["애정", c.love],
    ["직장·학업", c.career],
    ["건강", c.health],
    ["대인관계", c.relationship],
  ];
  const sorted = [...entries].sort((a, b) => b[1] - a[1]);
  const top = sorted.slice(0, 2).map(([k]) => k);
  const bottom = sorted[sorted.length - 1];

  // summary (사주 용어 노출 없이 밴드별 쉬운 한 줄)
  const overallBand = band(c.overall);
  const overallPhrase =
    overallBand === "high"
      ? "전반적으로 흐름이 순한 편이라 하려던 일을 밀어붙여 볼 만한 날"
      : overallBand === "mid"
        ? "크게 흔들리지 않는 무난한 흐름이라 페이스를 지키기 좋은 날"
        : "기운이 조금 눌리는 편이라 무리하기보다 살피며 가는 게 편한 날";
  const summary = `오늘은 ${overallPhrase}이에요.`;

  // overall (총운 카드용 2~3문장, top/bottom 분야를 종합)
  const overallLead =
    overallBand === "high"
      ? "오늘은 전반적으로 흐름이 좋은 편이에요."
      : overallBand === "mid"
        ? "오늘은 크게 무리 없는 무난한 흐름이에요."
        : "오늘은 기운이 조금 눌리는 편이라 페이스 조절이 필요해요.";
  const bottomLine =
    band(bottom[1]) === "low"
      ? `${bottom[0]}은(는) 조금만 살피면서 움직이면 무난해요.`
      : `${bottom[0]}도 무리하지 않는 선에서 챙기면 좋아요.`;
  const overall = `${overallLead} 특히 ${top.join(", ")} 쪽이 잘 풀리기 좋고, ${bottomLine}`;

  // keywords (전문용어 대신 쉬운 단어)
  const keywords = [
    GROUP_KEYWORD[e.tenGod.group],
    goodRel ? RELATION_KEYWORD_GOOD : cautionRel ? RELATION_KEYWORD_CAUTION : `${top[0]} 집중`,
    e.sinsal.hits.length ? "좋은 인연" : e.elementSupport.score >= 0 ? "안정" : "재정비",
  ].slice(0, 3);

  // do_actions
  const doActions = [
    GROUP_DO[e.tenGod.group],
    `행운 시간대 ${e.luckyItems.timeSlot.zhi}시(${e.luckyItems.timeSlot.range})에 중요한 일을 배치해보기`,
    `${e.luckyItems.colors[0]} 계열 소품이나 ${e.luckyItems.direction} 방향을 가볍게 활용해보기`,
  ];

  // avoid_actions
  const avoidActions: string[] = [];
  if (cautionRel === "충") avoidActions.push("확정 안 된 계획을 무리하게 밀어붙이는 것");
  else if (cautionRel === "형" || cautionRel === "원진") avoidActions.push("감정이 상한 상태에서 바로 대응하거나 답장하는 것");
  else avoidActions.push("한꺼번에 여러 일을 벌여 에너지를 분산시키는 것");
  avoidActions.push(
    e.elementSupport.score < 0
      ? "몸이 보내는 피로 신호를 무시하고 밤늦게까지 무리하는 것"
      : `${bottom[0]} 관련해서 오늘 당장 큰 결정을 내리는 것`,
  );

  // categories: 점수 코멘트 + (top 분야엔 good, bottom 분야엔 caution)
  const topSet = new Set(top);
  const goodText = (label: string): string =>
    label === top[0]
      ? e.sinsal.cheoneulgwiin
        ? "귀인의 도움이나 좋은 인연이 닿기 쉬운 기운이 있어요"
        : goodRel && RELATION_GOOD[goodRel]
          ? RELATION_GOOD[goodRel]!
          : `${label} 쪽이 상대적으로 잘 풀리기 쉬운 흐름이에요`
      : `${label} 쪽도 함께 순조롭게 흘러가기 좋아요`;
  const cautionText = (label: string): string =>
    e.sinsal.gongmang
      ? "기운이 살짝 흩어지기 쉬운 날이라 중요한 결정은 서두르지 않는 편이 좋아요"
      : cautionRel && RELATION_CAUTION[cautionRel]
        ? RELATION_CAUTION[cautionRel]!
        : `${label} 쪽은 오늘 무리하지 않는 선에서 가면 좋아요`;

  function buildCategory(label: string, comment: string): FortuneCategoryContent {
    const content: FortuneCategoryContent = { comment };
    if (topSet.has(label)) content.good = goodText(label);
    if (label === bottom[0]) content.caution = cautionText(label);
    return content;
  }

  const categories: FortuneContent["categories"] = {
    money: buildCategory(
      "재물",
      pick(c.money, "실속 있는 결과를 챙기기 좋아요.", "수입과 지출의 균형을 보기 좋은 날이에요.", "충동적인 지출은 하루 미뤄두면 좋아요."),
    ),
    love: buildCategory(
      "애정",
      pick(c.love, "마음을 표현하기 좋은 흐름이에요.", "가볍게 안부를 나누기 좋은 날이에요.", "혼자만의 시간도 나쁘지 않은 날이에요."),
    ),
    career: buildCategory(
      "직장·학업",
      pick(c.career, "집중이 잘 붙어 성과로 이어지기 쉬워요.", "할 일을 차분히 처리하기 좋아요.", "욕심내기보다 마무리에 집중하면 좋아요."),
    ),
    health: buildCategory(
      "건강",
      pick(c.health, "몸이 가벼워 활동적으로 보내기 좋아요.", "무리하지 않으면 무난해요.", "휴식과 수면을 우선으로 챙겨보세요."),
    ),
    relationship: buildCategory(
      "대인관계",
      pick(c.relationship, "사람들과 손발이 잘 맞아요.", "무난하게 어울리기 좋아요.", "거리 조절로 에너지를 아끼면 좋아요."),
    ),
  };

  // share_text
  const shareText = [
    `오늘의 운세 (${e.date} ${e.weekday})`,
    `${summary}`,
    `잘 풀리는 곳: ${top.join(", ")} / 오늘 체크: ${bottom[0]}`,
    `행운: ${e.luckyItems.colors[0]}·${e.luckyItems.direction}·${e.luckyItems.numbers.join(",")} · ${e.luckyItems.timeSlot.zhi}시`,
  ].join("\n");

  return {
    summary,
    overall,
    keywords,
    do_actions: doActions.slice(0, 3),
    avoid_actions: avoidActions.slice(0, 2),
    categories,
    share_text: shareText,
  };
}
