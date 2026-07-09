import type { GoosebumpGuess, GoosebumpReport, LifeDomain, PastYearRawSignal } from "../types/index.js";
import { DOMAIN_LABEL, domainVerb } from "./eventEngine.js";
import { domainsOfGanZhi } from "./pastValidation.js";

/**
 * 소름 엔진 (C-1, 재기획안 §7).
 *
 * pastValidation.ts(사용자 입력 → 계산 흐름과의 부합도 채점)의 방향을 뒤집는다: 사용자가 아무것도
 * 입력하지 않아도, 계산된 대운·세운에서 신호가 가장 강한 (연도, 분야) 조합 2~3개를 시스템이 먼저
 * 골라 "맞나요?"로 제시한다("2023년 무렵, 일·거처에 큰 변화의 흐름 — 맞나요?").
 *
 * 원칙(§7): "확신 없는 해는 말하지 않는다 — 빗나감 1개가 적중 3개를 지운다." 그래서 이 엔진은
 * pastValidation의 "strong" 등급(세운·대운 십성이 그 분야와 맞고, 상호작용이 실제로 있는 경우)에
 * 해당하는 조합만 후보로 삼는다. 강한 신호가 없으면 guesses는 빈 배열을 반환한다 — 억지로
 * 채우지 않는다.
 *
 * saju.ts를 import하지 않는다(pastValidation.ts와 동일 원칙) — computePastYearRawSignals가
 * 이미 계산해 순수 값으로 넘겨준다.
 */

const ALL_DOMAINS: LifeDomain[] = ["career", "money", "love", "health", "family", "move", "startup"];

interface Candidate {
  year: number;
  domain: LifeDomain;
  strength: number;
  evidence: string[];
}

function candidatesOfYear(dayGan: string, signal: PastYearRawSignal): Candidate[] {
  const se = domainsOfGanZhi(dayGan, signal.yearGanZhi);
  const dae = domainsOfGanZhi(dayGan, signal.daYunGanZhi);
  const interactionCount = signal.interactions.length;
  if (interactionCount === 0) return [];

  const candidates: Candidate[] = [];
  for (const domain of ALL_DOMAINS) {
    const hitBySe = se.domains.has(domain);
    const hitByDae = dae.domains.has(domain);
    // pastValidation.matchOne의 "strong" 기준과 동일: 십성 부합 + 그 시기 실제 변동(상호작용)
    if (!hitBySe && !hitByDae) continue;

    const evidence: string[] = [
      `세운 ${signal.yearGanZhi}${se.groups.length > 0 ? ` (${se.groups.join("·")})` : ""}`,
    ];
    if (signal.daYunGanZhi) evidence.push(`대운 ${signal.daYunGanZhi}${dae.groups.length > 0 ? ` (${dae.groups.join("·")})` : ""}`);
    evidence.push(`상호작용 ${interactionCount}건: ${signal.interactions.slice(0, 3).join("; ")}`);

    const strength = interactionCount * 2 + (hitBySe ? 1 : 0) + (hitByDae ? 1 : 0);
    candidates.push({ year: signal.year, domain, strength, evidence });
  }
  return candidates;
}

/**
 * 소름 엔진 리포트를 만든다. 강한 신호가 있는 (연도, 분야) 중 상위 몇 개만 고른다.
 * 한 해에서 여러 분야가 동시에 강하게 나오면 그 해에서 가장 강한 분야 하나만 남긴다(한 해를
 * 여러 번 되묻지 않기 위함) — 그 다음 연도 간 강도로 정렬해 상위 maxGuesses개를 취한다.
 */
export function buildGoosebumpReport(
  dayMasterGan: string,
  rawSignals: PastYearRawSignal[],
  options: { maxGuesses?: number } = {},
): GoosebumpReport {
  const maxGuesses = options.maxGuesses ?? 3;

  const byYear = new Map<number, Candidate>();
  for (const signal of rawSignals) {
    for (const candidate of candidatesOfYear(dayMasterGan, signal)) {
      const current = byYear.get(candidate.year);
      if (!current || candidate.strength > current.strength) byYear.set(candidate.year, candidate);
    }
  }

  const top = [...byYear.values()].sort((a, b) => b.strength - a.strength || b.year - a.year).slice(0, maxGuesses);

  const guesses: GoosebumpGuess[] = top
    .sort((a, b) => a.year - b.year)
    .map((c) => ({
      year: c.year,
      domain: c.domain,
      domainLabel: DOMAIN_LABEL[c.domain],
      prompt: `${c.year}년 무렵, ${domainVerb(c.domain)} 흐름이 있었을 것 같아요 — 맞나요?`,
      strength: c.strength,
      evidence: c.evidence,
    }));

  return { guesses };
}
