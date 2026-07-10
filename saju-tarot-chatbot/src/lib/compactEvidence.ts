import type { EventForecast, EventScenario, Gender, LuckCycles, SajuChart, SinsalHit } from "../types/index.js";
import { buildEventForecast, groupOf, type TenGodGroup } from "./eventEngine.js";

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

/** 자평진전 격국 심화 요약 (chart.gyeokguk / gyeokguk.classic 읽기 전용 압축) */
export interface CompactStructure {
  name: string;
  status?: string;
  /** 상신: 격을 완성시키는 핵심 십성. 예: "정관(금) — 원국에 있음" */
  sangshin?: string;
  /** 성격 패턴 이름 (예: "식신생재(食神生財)") */
  pattern?: string;
  /** 파격 요인 이름 목록 (예: "상관견관(傷官見官)") */
  failures: string[];
  /** 종격 이름 (일반격이면 없음) */
  jonggyeok?: string;
  established?: "성격" | "파격" | "미형성";
  note: string;
}

/** 연해자평 십성 세기 분포 요약 (chart.tenGodDistribution 그룹 집계) */
export interface CompactTenGodProfile {
  groups: Record<TenGodGroup, number>;
  /** 가장 강한 그룹(들) */
  dominant: TenGodGroup[];
  /** 원국(지장간 포함)에 아예 없는 그룹(들) */
  missing: TenGodGroup[];
}

/** 궁통보감 조후 요약 (chart.yongshin.climaticClassic 읽기 전용 압축) */
export interface CompactClimateClassic {
  /** 우선순위 조후 천간 (예: ["계","정"]) */
  priorityStems: string[];
  primaryElement: string;
  satisfied: boolean;
  missingStems: string[];
  note: string;
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
  /**
   * 이하 4대 고전 심화 필드 (엔진 업그레이드 S-1, docs/engine-upgrade-2026-07.md).
   * chart의 기존 계산값을 읽기 전용으로 압축해 노출만 한다 — evidenceIds/ruleEngine에는
   * 의도적으로 연결하지 않음(JudgmentPack·golden 케이스 불변, 룰 연결은 S-2에서).
   */
  structure?: CompactStructure;
  tenGodProfile?: CompactTenGodProfile;
  climateClassic?: CompactClimateClassic;
  /** 핵심 신살 최대 6개 (중요도 순) */
  sinsalTop?: SinsalHit[];
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
  if (chart.gyeokguk) ids.structure = `${chart.gyeokguk.name}${chart.gyeokguk.status ? ` (${chart.gyeokguk.status})` : ""}`;
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

function buildStructure(chart: SajuChart): CompactStructure | undefined {
  const gyeokguk = chart.gyeokguk;
  if (!gyeokguk) return undefined;
  const classic = gyeokguk.classic;
  return {
    name: gyeokguk.name,
    status: gyeokguk.status,
    sangshin: classic?.sangshin
      ? `${classic.sangshin.tenGod}(${classic.sangshin.element}) — ${classic.sangshin.present ? "원국에 있음" : "원국에 뚜렷하지 않음"}`
      : undefined,
    pattern: classic?.pattern,
    failures: classic?.failures.map((f) => f.name) ?? [],
    jonggyeok: classic?.jonggyeok?.name,
    established: classic?.established,
    note: classic?.note ?? gyeokguk.gloss,
  };
}

function buildTenGodProfile(chart: SajuChart): CompactTenGodProfile | undefined {
  const dist = chart.tenGodDistribution;
  if (!dist || Object.keys(dist).length === 0) return undefined;
  const groups: Record<TenGodGroup, number> = { 비겁: 0, 식상: 0, 재성: 0, 관성: 0, 인성: 0 };
  for (const [tenGod, value] of Object.entries(dist)) {
    const group = groupOf(tenGod);
    if (group) groups[group] += value;
  }
  for (const key of Object.keys(groups) as TenGodGroup[]) groups[key] = Math.round(groups[key] * 100) / 100;
  const entries = Object.entries(groups) as Array<[TenGodGroup, number]>;
  const max = Math.max(...entries.map(([, value]) => value));
  return {
    groups,
    dominant: max > 0 ? entries.filter(([, value]) => value === max).map(([key]) => key) : [],
    missing: entries.filter(([, value]) => value === 0).map(([key]) => key),
  };
}

function buildClimateClassic(chart: SajuChart): CompactClimateClassic | undefined {
  const classic = chart.yongshin?.climaticClassic;
  if (!classic) return undefined;
  return {
    priorityStems: classic.priorityStems,
    primaryElement: classic.primaryElement,
    satisfied: classic.satisfied,
    missingStems: classic.missingStems,
    note: classic.note,
  };
}

/** 기본 리딩에서 우선 언급할 가치가 큰 신살 순서 (앞일수록 중요) */
const KEY_SINSAL_ORDER = [
  "천을귀인", "괴강", "백호", "양인", "역마", "도화", "화개",
  "원진", "귀문", "문창", "천덕", "월덕", "고신", "과숙",
];

function buildSinsalTop(chart: SajuChart, limit = 6): SinsalHit[] | undefined {
  const hits = chart.sinsal;
  if (!hits || hits.length === 0) return undefined;
  const rank = (hit: SinsalHit) => {
    const idx = KEY_SINSAL_ORDER.findIndex((name) => hit.name.includes(name));
    return idx === -1 ? KEY_SINSAL_ORDER.length : idx;
  };
  return [...hits].sort((a, b) => rank(a) - rank(b)).slice(0, limit);
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
    structure: buildStructure(chart),
    tenGodProfile: buildTenGodProfile(chart),
    climateClassic: buildClimateClassic(chart),
    sinsalTop: buildSinsalTop(chart),
  };
}

export function formatCompactEvidence(evidence: CompactEvidence): string {
  return JSON.stringify(evidence, null, 2);
}
