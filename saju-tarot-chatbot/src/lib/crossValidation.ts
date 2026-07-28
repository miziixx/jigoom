import type {
  CrossValidationLevel,
  CrossValidationMatch,
  CrossValidationReport,
  Gender,
  LuckCycles,
  SajuChart,
} from "../types/index.js";
import { buildEventForecast } from "./eventEngine.js";
import { deriveZiweiDomainVerdicts, deriveZiweiLuckVerdicts } from "./ziweiInterpretation.js";
import type { ZiweiChart, ZiweiLuck } from "./ziwei.js";

/**
 * 사주 ↔ 자미두수 교차검증 (무 API·결정론).
 *
 * 목적: 같은 생년월일시로 사주와 자미두수가 각 분야를 어떻게 보는지 대조해, 두 방식이 같은 방향이면
 * 확신을 높이고 갈리면 "방식에 따라 다를 수 있다"고 조심스럽게 짚는다. 앱의 "근거 있는" 강점을 살린다.
 *
 * 설계:
 *   - 사주 쪽: eventEngine의 분야 balance(opportunity/caution/mixed/calm)를 좋음/보통/주의로 환산.
 *   - 자미두수 쪽: deriveZiweiDomainVerdicts의 궁별 tone(좋음/보통/주의).
 *   - 두 방식이 모두 판정하는 분야(직업·재물·애정·건강·가족)만 비교한다.
 *   - 이건 두 거친 신호의 '방향' 대조다. 단정 근거가 아니라 확신 조절용 참고 신호로만 쓴다.
 */

const SAJU_TONE: Record<string, string> = {
  opportunity: "좋음",
  caution: "주의",
  mixed: "보통",
  calm: "보통",
};

function levelOf(a: string, b: string): CrossValidationLevel {
  if (a === b) return "강일치";
  if ((a === "좋음" && b === "주의") || (a === "주의" && b === "좋음")) return "불일치";
  return "부분일치";
}

function summaryOf(label: string, level: CrossValidationLevel, tone: string): string {
  if (level === "강일치")
    return tone === "주의"
      ? `${label}은 두 방식 모두 조심하라고 봅니다 — 이 부분은 더 또렷하게 짚어도 됩니다.`
      : tone === "좋음"
        ? `${label}은 두 방식 모두 좋게 봅니다 — 이 부분은 더 자신 있게 말해도 됩니다.`
        : `${label}은 두 방식 모두 담담하게 봅니다 — 무난한 편으로 다룹니다.`;
  if (level === "불일치")
    return `${label}은 두 방식이 서로 다르게 봅니다 — 단정하지 말고 "방식에 따라 갈릴 수 있다"고 조심스럽게 다룹니다.`;
  return `${label}은 한쪽은 뚜렷하고 한쪽은 담담합니다 — 참고만 하고 과하게 확신하지 않습니다.`;
}

/**
 * 사주 차트·운과 자미두수 원식을 대조해 교차검증 리포트를 만든다.
 * 자미두수 차트가 없으면(시간 미상·팔자만 입력 등) null.
 */
export function buildCrossValidation(
  sajuChart: SajuChart,
  ziweiChart: ZiweiChart | null | undefined,
  luck?: LuckCycles,
  gender?: Gender,
  ziweiLuck?: ZiweiLuck | null,
): CrossValidationReport | null {
  if (!ziweiChart) return null;

  const forecast = buildEventForecast(sajuChart, luck, gender);
  if (!forecast) return null;
  const sajuByDomain = new Map(forecast.domains.map((d) => [d.domain as string, d]));
  const ziweiVerdicts = deriveZiweiDomainVerdicts(ziweiChart);

  const matches: CrossValidationMatch[] = [];
  for (const zv of ziweiVerdicts) {
    const sajuDomain = sajuByDomain.get(zv.domain);
    if (!sajuDomain) continue; // 두 방식 다 판정하는 분야만 (mental 등은 사주 측 없음)
    const sajuTone = SAJU_TONE[sajuDomain.scores.balance] ?? "보통";
    const level = levelOf(sajuTone, zv.tone);
    matches.push({
      domain: zv.domain,
      label: zv.label,
      level,
      sajuTone,
      ziweiTone: zv.tone,
      summary: summaryOf(zv.label, level, sajuTone),
      evidence: [`사주 흐름: ${sajuDomain.label} ${sajuTone}(${sajuDomain.scores.balance})`, `자미두수: ${zv.evidence}`],
    });
  }
  if (matches.length === 0) return null;

  const strong = matches.filter((m) => m.level === "강일치").length;
  const agreementScore = Math.round((strong / matches.length) * 100);
  const strongLabels = matches.filter((m) => m.level === "강일치").map((m) => m.label);
  const clashLabels = matches.filter((m) => m.level === "불일치").map((m) => m.label);

  let headline: string;
  if (strongLabels.length > 0 && clashLabels.length > 0)
    headline = `사주와 자미두수가 ${strongLabels.slice(0, 2).join("·")}에서는 같은 방향이고, ${clashLabels.slice(0, 2).join("·")}에서는 갈립니다.`;
  else if (strongLabels.length > 0)
    headline = `사주와 자미두수가 ${strongLabels.slice(0, 3).join("·")}에서 같은 방향으로 모입니다 — 이 축은 더 믿고 볼 만합니다.`;
  else if (clashLabels.length > 0)
    headline = `사주와 자미두수가 ${clashLabels.slice(0, 2).join("·")}에서 갈립니다 — 이 축은 조심스럽게 다룹니다.`;
  else headline = "사주와 자미두수가 대체로 담담하게, 큰 충돌 없이 봅니다.";

  // ── 운한 대조 축 (Z-4): 사주 종합 흐름(forecast, 대운·세운 반영) ↔ 자미 올해(유년) 흐름 ──────────
  let luckMatches: CrossValidationMatch[] | undefined;
  let luckHeadline: string | undefined;
  if (ziweiLuck?.year) {
    const yearVerdicts = deriveZiweiLuckVerdicts(ziweiChart, { ...ziweiLuck, decade: null }); // 유년만
    const lm: CrossValidationMatch[] = [];
    for (const zv of yearVerdicts) {
      const sajuDomain = sajuByDomain.get(zv.domain);
      if (!sajuDomain) continue;
      const sajuTone = SAJU_TONE[sajuDomain.scores.balance] ?? "보통";
      const level = levelOf(sajuTone, zv.tone);
      lm.push({
        domain: zv.domain,
        label: zv.label,
        level,
        sajuTone,
        ziweiTone: zv.tone,
        summary: `올해 ${zv.label}: ${summaryOf(zv.label, level, sajuTone)}`,
        evidence: [`사주 흐름: ${sajuDomain.label} ${sajuTone}`, `자미 유년: ${zv.evidence}`],
      });
    }
    if (lm.length > 0) {
      luckMatches = lm;
      const agree = lm.filter((m) => m.level === "강일치").map((m) => m.label);
      const clash = lm.filter((m) => m.level === "불일치").map((m) => m.label);
      luckHeadline =
        agree.length > 0 && clash.length > 0
          ? `올해는 ${agree.slice(0, 2).join("·")}에서 두 방식이 같은 방향, ${clash.slice(0, 2).join("·")}에서는 갈립니다.`
          : agree.length > 0
            ? `올해는 ${agree.slice(0, 3).join("·")}에서 두 방식이 같은 방향으로 모입니다.`
            : clash.length > 0
              ? `올해는 ${clash.slice(0, 2).join("·")}에서 두 방식이 갈리니 조심스럽게 봅니다.`
              : "올해는 두 방식 모두 큰 충돌 없이 담담하게 봅니다.";
    }
  }

  return { headline, agreementScore, matches, luckMatches, luckHeadline };
}
