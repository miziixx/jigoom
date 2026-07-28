import type {
  LifeDomain,
  PastEventCalibrationInput,
  PastEventMatch,
  PastValidationReport,
} from "../types/index.js";
import {
  DOMAIN_LABEL,
  GROUP_DOMAINS,
  ZHI_MAIN_STEM_TABLE,
  groupOf,
  tenGodOf,
  type TenGodGroup,
} from "./eventEngine.js";

/**
 * 과거 검증 판정층 (무 API·결정론, saju.ts 미import).
 *
 * 목적(로드맵 2번): 사용자가 실제 과거 사건(예: 2021년 이직)을 입력하면, 그 해 세운·대운 흐름이
 * 그 분야와 계산상 부합하는지 판정한다. 부합한 축은 이번 리딩에서 더 신뢰하고, 계산상 뚜렷한
 * 신호가 없던 사건은 "이 사주에서는 다른 축으로 봐야 할 수 있다"는 조심스러운 신호로 삼는다.
 *
 * 원칙(CLAUDE.md):
 *   - "이 사주는 맞다/틀리다"로 단정하지 않는다. 부합/불일치는 해석 신뢰도 보정 참고일 뿐이다.
 *   - 표면 문구는 쉬운 말, 전문 용어(십성·세운·대운)는 evidence에만.
 *   - 계산 자체(간지·상호작용)는 saju.ts에서 이미 끝났고, 여기서는 매핑·판정만 한다.
 */

/** 간지의 천간·지지 정기 십성 그룹을 뽑아 분야 집합으로 (goosebumpEngine.ts와 공용) */
export function domainsOfGanZhi(dayGan: string, ganZhi: string | null): { groups: TenGodGroup[]; domains: Set<LifeDomain> } {
  const domains = new Set<LifeDomain>();
  const groups: TenGodGroup[] = [];
  if (!ganZhi || ganZhi.length < 2) return { groups, domains };
  const stemGroup = groupOf(tenGodOf(dayGan, ganZhi[0]));
  const mainStem = ZHI_MAIN_STEM_TABLE[ganZhi[1]];
  const branchGroup = mainStem ? groupOf(tenGodOf(dayGan, mainStem)) : null;
  for (const g of [stemGroup, branchGroup]) {
    if (!g) continue;
    groups.push(g);
    for (const d of GROUP_DOMAINS[g]) domains.add(d);
  }
  return { groups, domains };
}

const LEVEL_WORD: Record<PastEventMatch["level"], string> = {
  strong: "계산 흐름과 잘 맞습니다",
  partial: "일부 맞아떨어집니다",
  weak: "계산상 뚜렷한 신호는 약합니다",
};

function matchOne(dayGan: string, input: PastEventCalibrationInput): PastEventMatch {
  const se = domainsOfGanZhi(dayGan, input.yearGanZhi);
  const dae = domainsOfGanZhi(dayGan, input.daYunGanZhi);
  const domainHitBySe = se.domains.has(input.domain);
  const domainHitByDae = dae.domains.has(input.domain);
  const interactionCount = input.interactions.length;
  const domainLabel = DOMAIN_LABEL[input.domain];

  // 판정: 십성(세운/대운) 부합 + 그 시기 변동(상호작용) 강도
  let level: PastEventMatch["level"];
  if ((domainHitBySe || domainHitByDae) && interactionCount >= 1) level = "strong";
  else if (domainHitBySe || domainHitByDae || interactionCount >= 2) level = "partial";
  else level = "weak";

  const summary =
    level === "strong"
      ? `${input.year}년 ${domainLabel} 사건은 그 시기 흐름과 잘 맞습니다. 이 사주에서 ${domainLabel} 축은 신뢰도가 높은 편입니다.`
      : level === "partial"
        ? `${input.year}년 ${domainLabel} 사건은 그 시기 흐름과 일부 맞아떨어집니다. 참고 축으로 볼 만합니다.`
        : `${input.year}년 ${domainLabel} 사건은 계산상 뚜렷한 신호가 약합니다. 이 부분은 다른 축(성격·환경·선택)의 영향이 컸을 수 있습니다.`;

  const evidence: string[] = [];
  evidence.push(`세운 ${input.yearGanZhi}${se.groups.length > 0 ? ` (${se.groups.join("·")})` : ""}`);
  if (input.daYunGanZhi) evidence.push(`대운 ${input.daYunGanZhi}${dae.groups.length > 0 ? ` (${dae.groups.join("·")})` : ""}`);
  if (interactionCount > 0) evidence.push(`상호작용 ${interactionCount}건: ${input.interactions.slice(0, 3).join("; ")}`);
  evidence.push(`판정: ${LEVEL_WORD[level]}`);

  return {
    year: input.year,
    domain: input.domain,
    domainLabel,
    note: input.note,
    level,
    summary,
    evidence,
  };
}

export function buildPastValidationReport(
  dayMasterGan: string,
  inputs: PastEventCalibrationInput[],
): PastValidationReport | null {
  if (inputs.length === 0) return null;
  const matches = inputs
    .slice()
    .sort((a, b) => a.year - b.year)
    .map((input) => matchOne(dayMasterGan, input));

  const strong = matches.filter((m) => m.level === "strong");
  const weak = matches.filter((m) => m.level === "weak");
  const reliableDomains = [...new Set(strong.map((m) => m.domain))];

  let headline: string;
  if (strong.length > 0 && weak.length === 0) {
    headline = `입력하신 과거 사건들이 계산된 흐름과 대체로 잘 맞습니다. 특히 ${[...new Set(strong.map((m) => m.domainLabel))].join("·")} 축은 이 리딩에서 더 믿고 봐도 좋습니다.`;
  } else if (strong.length > 0) {
    headline = `일부 사건은 흐름과 잘 맞고, 일부는 계산 신호가 약합니다. 잘 맞은 축은 신뢰하고, 약한 축은 조심스럽게 참고하세요.`;
  } else {
    headline = `입력하신 사건들은 계산 흐름과 뚜렷하게 맞아떨어지지는 않습니다. 이 사주는 사건 시기보다 성향·선택의 영향이 더 큰 유형일 수 있습니다.`;
  }

  return { matches, headline, reliableDomains };
}
