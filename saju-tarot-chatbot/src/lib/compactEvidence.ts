import type { EventForecast, EventScenario, Gender, LuckCycles, SajuChart } from "../types/index.js";
import { buildEventForecast } from "./eventEngine.js";

type FiveElementKey = keyof SajuChart["fiveElements"];

export interface CompactDomainScore {
  domain: string;
  label: string;
  activation: EventScenario["activation"];
  balance: EventScenario["scores"]["balance"];
  activationScore: number;
  benefit: number;
  risk: number;
  summary: string;
  evidenceIds: string[];
}

export interface CompactEvidence {
  dayMaster: string;
  strength: {
    label: string;
    detail: string;
  } | null;
  elementFlow: {
    strongest: string[];
    weakest: string[];
    balance: SajuChart["fiveElements"];
  };
  usefulElements: {
    yongshin: string[];
    heesin: string[];
    unfavorable: string[];
    note: string;
  };
  topFindings: string[];
  domainScores: CompactDomainScore[];
  riskFlags: string[];
  evidenceIds: Record<string, string>;
}

const ELEMENT_LABEL: Record<FiveElementKey, string> = {
  wood: "목",
  fire: "화",
  earth: "토",
  metal: "금",
  water: "수",
};

function strongestWeakest(balance: SajuChart["fiveElements"]) {
  const entries = (Object.keys(balance) as FiveElementKey[]).map((key) => ({ key, label: ELEMENT_LABEL[key], value: balance[key] }));
  const max = Math.max(...entries.map((e) => e.value));
  const min = Math.min(...entries.map((e) => e.value));
  return {
    strongest: entries.filter((e) => e.value === max).map((e) => e.label),
    weakest: entries.filter((e) => e.value === min).map((e) => e.label),
  };
}

function evidenceMap(chart: SajuChart, luck?: LuckCycles): Record<string, string> {
  const ids: Record<string, string> = {
    natal_core: `일주 ${chart.day.ganZhi}, 일간 ${chart.dayMasterGan}`,
    five_elements: `오행 분포 목:${chart.fiveElements.wood} 화:${chart.fiveElements.fire} 토:${chart.fiveElements.earth} 금:${chart.fiveElements.metal} 수:${chart.fiveElements.water}`,
  };
  if (chart.strength) ids.strength = `강약 ${chart.strength.label}: ${chart.strength.detail}`;
  if (chart.yongshin) {
    ids.useful_elements = `용신 ${chart.yongshin.yongshin?.join("·") || chart.yongshin.supportive.join("·") || "없음"} / 희신 ${chart.yongshin.heesin?.join("·") || "없음"} / 기신 ${chart.yongshin.unfavorable.join("·") || "없음"}`;
  }
  if (chart.interactions && chart.interactions.length > 0) ids.natal_interactions = chart.interactions.slice(0, 4).join(", ");
  if (chart.gyeokguk) ids.structure = `${chart.gyeokguk.name}: ${chart.gyeokguk.basis}`;
  if (luck) {
    ids.current_luck = `현재 대운 ${luck.currentDaYun ?? "시작 전"} / 세운 ${luck.yearGanZhi} / 월운 ${luck.monthGanZhi}`;
    if (luck.daYunYearOverlap) ids.luck_overlap = luck.daYunYearOverlap.evidence.join(" / ");
    if (luck.luckInteractions && luck.luckInteractions.length > 0) ids.luck_interactions = luck.luckInteractions.slice(0, 5).join(", ");
  }
  return ids;
}

function domainEvidenceId(index: number): string {
  return `domain_${index + 1}`;
}

function domainScores(forecast: EventForecast | null, ids: Record<string, string>): CompactDomainScore[] {
  if (!forecast) return [];
  const ordered = [
    ...forecast.activeDomains.map((key) => forecast.domains.find((d) => d.domain === key)).filter((d): d is EventScenario => Boolean(d)),
    ...forecast.domains.filter((d) => !forecast.activeDomains.includes(d.domain)),
  ];
  return ordered.slice(0, 7).map((domain, index) => {
    const id = domainEvidenceId(index);
    ids[id] = [
      domain.evidence.length > 0 ? domain.evidence.join("; ") : `${domain.label}: 뚜렷한 전문 근거 적음`,
      domain.timingSignals.length > 0 ? `타이밍: ${domain.timingSignals.join(" / ")}` : "",
    ]
      .filter(Boolean)
      .join(" | ");
    return {
      domain: domain.domain,
      label: domain.label,
      activation: domain.activation,
      balance: domain.scores.balance,
      activationScore: domain.scores.activation,
      benefit: domain.scores.benefit,
      risk: domain.scores.risk,
      summary: domain.activationNote,
      evidenceIds: [id],
    };
  });
}

function topFindings(chart: SajuChart, forecast: EventForecast | null, luck?: LuckCycles): string[] {
  const findings: string[] = [];
  const flow = strongestWeakest(chart.fiveElements);
  findings.push(`핵심 기질은 일간 ${chart.dayMasterGan}과 강한 ${flow.strongest.join("·")} 흐름, 약한 ${flow.weakest.join("·")} 흐름의 조합으로 본다.`);
  if (chart.strength) findings.push(`힘의 세기는 ${chart.strength.label} 쪽으로 판정되어, 조언은 이 강약을 기준으로 속도와 부담을 조절한다.`);
  if (chart.yongshin) {
    const useful = [...(chart.yongshin.yongshin ?? chart.yongshin.supportive), ...(chart.yongshin.heesin ?? [])];
    if (useful.length > 0) findings.push(`보완하면 좋은 방향은 ${Array.from(new Set(useful)).join("·")}이며, 과해지면 부담되는 방향은 ${chart.yongshin.unfavorable.join("·") || "뚜렷하지 않음"}이다.`);
  }
  if (forecast?.headline) findings.push(forecast.headline);
  if (luck?.daYunYearOverlap) findings.push(luck.daYunYearOverlap.headline);
  return findings.slice(0, 5);
}

function riskFlags(chart: SajuChart, forecast: EventForecast | null, luck?: LuckCycles): string[] {
  const flags: string[] = [];
  if (!chart.hour) flags.push("출생 시간을 몰라 시주 기반 세부 성향과 시기 판단은 낮은 확신으로 말해야 한다.");
  if (chart.timeCorrection?.boundaryWarning) flags.push(chart.timeCorrection.boundaryWarning);
  const cautionDomains = forecast?.domains.filter((d) => d.scores.balance === "caution").slice(0, 3) ?? [];
  for (const d of cautionDomains) flags.push(`${d.label}: ${d.cautions[0] ?? d.activationNote}`);
  if (luck?.daYunYearOverlap?.combo === "amplify-bad") flags.push(luck.daYunYearOverlap.headline);
  return Array.from(new Set(flags)).slice(0, 5);
}

export function buildCompactEvidence(chart: SajuChart, luck?: LuckCycles, gender?: Gender): CompactEvidence {
  const forecast = buildEventForecast(chart, luck, gender);
  const ids = evidenceMap(chart, luck);
  const elementFlow = strongestWeakest(chart.fiveElements);
  return {
    dayMaster: chart.dayMasterGan,
    strength: chart.strength ? { label: chart.strength.label, detail: chart.strength.detail } : null,
    elementFlow: {
      ...elementFlow,
      balance: chart.fiveElements,
    },
    usefulElements: {
      yongshin: chart.yongshin?.yongshin ?? chart.yongshin?.supportive ?? [],
      heesin: chart.yongshin?.heesin ?? [],
      unfavorable: chart.yongshin?.unfavorable ?? [],
      note: chart.yongshin?.note ?? "용희기신 후보 없음",
    },
    topFindings: topFindings(chart, forecast, luck),
    domainScores: domainScores(forecast, ids),
    riskFlags: riskFlags(chart, forecast, luck),
    evidenceIds: ids,
  };
}

export function formatCompactEvidence(evidence: CompactEvidence): string {
  return JSON.stringify(evidence, null, 2);
}
