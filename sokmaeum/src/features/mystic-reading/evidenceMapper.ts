import { computeLuckCycles, computeSajuChart, ELEMENT_KO, GAN_WUXING, tenGodOf } from "../../lib/saju";
import { computeAstrologyProfile } from "../../lib/astrology";
import { branchRelationsBetween, tenGodGroupOf } from "../../lib/fortune";
import type {
  BirthInfo,
  FiveElementBalance,
  MysticEvidence,
  PartnerEvidence,
  ReadingInterest,
  SajuChart,
} from "../../types";

export interface MysticEvidenceOptions {
  /** 상대방 생년월일 (관계 리딩 확장용) */
  partner?: BirthInfo;
  /** 지난 피드백에서 뽑은 스타일 조정 힌트 */
  styleHint?: string;
}

/**
 * 속마음 리딩의 "근거 데이터"를 결정론적으로 산출한다.
 * LLM은 이 근거만 심리 문장으로 번역한다(사주를 새로 계산하지 않는다).
 *
 * 생성 순서(요구사항 준수):
 * 1) 사주 계산값(원국+대운/세운/월운)을 읽는다
 * 2) 가장 강한 오행 2~3개를 뽑는다
 * 3) 부족/과한 오행을 확인한다
 * 4) 십성 분포에서 행동 패턴을 추정한다
 * 5) 현재 세운/월운에서 "요즘 상태"를 만든다
 * 6) 관심사(interest)를 반영한다
 * 7) 각 결과에 근거(notes) 문자열을 남긴다
 */
export function buildMysticEvidence(
  birthInfo: BirthInfo,
  interest: ReadingInterest,
  now: Date = new Date(),
  options: MysticEvidenceOptions = {},
): MysticEvidence {
  const chart = computeSajuChart(birthInfo);
  const luck = computeLuckCycles(birthInfo, now, { includeMonthlyFlow: true });
  const astrology = computeAstrologyProfile(birthInfo);

  const hasHour = birthInfo.hour !== null;
  const notes: string[] = [];

  // ── 오행 강약 ──────────────────────────────
  const elementKeys = Object.keys(chart.fiveElements) as (keyof FiveElementBalance)[];
  const sorted = [...elementKeys].sort((a, b) => chart.fiveElements[b] - chart.fiveElements[a]);
  const maxCount = chart.fiveElements[sorted[0]];
  const total = elementKeys.reduce((s, k) => s + chart.fiveElements[k], 0) || 1;

  const strongElements = sorted
    .filter((k) => chart.fiveElements[k] >= Math.max(2, maxCount - 1) && chart.fiveElements[k] > 0)
    .slice(0, 3)
    .map((k) => ELEMENT_KO[k]);
  const weakElements = elementKeys
    .filter((k) => chart.fiveElements[k] === 0)
    .map((k) => ELEMENT_KO[k]);

  strongElements.forEach((el) => notes.push(`${el} 기운 강함`));
  weakElements.forEach((el) => notes.push(`${el} 기운 부족`));
  // 과다(전체의 40% 이상 한 오행에 몰림)
  const overloaded = sorted.filter((k) => chart.fiveElements[k] / total >= 0.4).map((k) => ELEMENT_KO[k]);
  overloaded.forEach((el) => notes.push(`${el} 기운 과다(에너지 편중)`));

  // ── 십성 그룹 분포(비겁/식상/재성/관성/인성) ──
  const tenGodGroups: Record<string, number> = { 비겁: 0, 식상: 0, 재성: 0, 관성: 0, 인성: 0 };
  const tenGodNames: string[] = [];
  for (const entry of chart.tenGods) {
    // "연간 갑: 편재" 형태 → 콜론 뒤 십성 이름
    const name = entry.split(":").pop()?.trim() ?? "";
    if (name && name !== "출생시간 모름") tenGodNames.push(name);
  }
  for (const entry of chart.branchTenGods ?? []) {
    // "연지 자(정기 계): 정인" 형태
    const name = entry.split(":").pop()?.trim() ?? "";
    if (name) tenGodNames.push(name);
  }
  for (const name of tenGodNames) {
    const group = tenGodGroupOf(name);
    tenGodGroups[group] = (tenGodGroups[group] ?? 0) + 1;
  }
  const dominantTenGods = Object.entries(tenGodGroups)
    .filter(([, v]) => v > 0)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 2)
    .map(([k]) => k);
  dominantTenGods.forEach((g) => notes.push(`${g} 강함`));

  // ── 용신/기신 ──────────────────────────────
  const yongshin = chart.yongshin?.supportive ?? [];
  const gishin = chart.yongshin?.unfavorable ?? [];
  if (yongshin.length > 0) notes.push(`용신/희신: ${yongshin.join("·")}`);

  // ── 신강/신약 ──────────────────────────────
  const strength = chart.strength?.label ?? "중화";
  notes.push(`일간 세력: ${strength}`);

  // ── 원국 합충형파해 / 신살 ──────────────────
  const natalInteractions = chart.interactions ?? [];
  natalInteractions.slice(0, 4).forEach((i) => notes.push(`원국 ${i}`));
  // 신살: 같은 신살의 여러 위치를 한 줄로 합치고 길신/흉살/특수로 그룹핑해 정리
  const sinsalByName = new Map<string, { category: string; gloss: string; positions: string[] }>();
  for (const s of chart.sinsal ?? []) {
    const cur = sinsalByName.get(s.name);
    if (cur) cur.positions.push(s.position);
    else sinsalByName.set(s.name, { category: s.category, gloss: s.gloss, positions: [s.position] });
  }
  const byCategory: Record<string, string[]> = { 길신: [], 흉살: [], 특수: [] };
  for (const [name, info] of sinsalByName) {
    byCategory[info.category]?.push(`${name}(${info.positions.join("·")})`);
  }
  const sinsal: string[] = [];
  for (const cat of ["길신", "흉살", "특수"] as const) {
    if (byCategory[cat].length > 0) sinsal.push(`[${cat}] ${byCategory[cat].join(", ")}`);
  }
  if (chart.gongmang) sinsal.push(`[특수] ${chart.gongmang}`);
  // 대표 신살만 notes에 강조: 길신·흉살 각 최대 2개 (이름 단위, 위치 합침)
  for (const cat of ["길신", "흉살"] as const) {
    byCategory[cat].slice(0, 2).forEach((label) => notes.push(`${cat} ${label}`));
  }

  // ── 격국 / 일주 성향 ────────────────────────
  if (chart.gyeokguk) notes.push(`격국: ${chart.gyeokguk.name} — ${chart.gyeokguk.gloss}`);
  if (chart.iljuTrait) notes.push(`일주 성향: ${chart.iljuTrait}`);

  // ── 현재 운(대운/세운/월운) ──────────────────
  const luckInteractions = luck.luckInteractions ?? [];
  luckInteractions.slice(0, 4).forEach((i) => notes.push(`현재 운: ${i}`));
  if (luckInteractions.some((i) => i.includes("충"))) notes.push("현재 운에서 충 발생(변동 흐름)");

  // ── 관심사 반영 ─────────────────────────────
  notes.push(`현재 관심사: ${INTEREST_LABEL[interest]}`);
  astrology.notes.slice(0, 3).forEach((note) => notes.push(`점성술 ${note}`));

  // ── 출생시간 ────────────────────────────────
  if (!hasHour) notes.push("출생시간 미입력으로 시주 해석 제외");

  // ── 상대방(관계 리딩 확장) ──────────────────
  let partner: PartnerEvidence | undefined;
  if (options.partner) {
    partner = buildPartnerEvidence(chart, options.partner);
    notes.push(`상대방 입력됨 (관계 대조: ${partner.elementRelation})`);
  }

  return {
    interest,
    hasHour,
    dayMaster: chart.dayMasterGan,
    dayMasterElement: ELEMENT_KO[elementOfGan(chart.dayMasterGan)] ?? "",
    monthBranch: chart.month.zhi,
    strength,
    strongElements,
    weakElements,
    tenGodGroups,
    dominantTenGods,
    yongshin,
    gishin,
    natalInteractions,
    sinsal,
    astrology,
    currentDaYun: luck.currentDaYun,
    yearGanZhi: luck.yearGanZhi,
    monthGanZhi: luck.monthGanZhi,
    luckInteractions,
    monthlyFlow: (luck.monthlyFlow ?? []).map((m) => ({
      month: m.month,
      ganZhi: m.ganZhi,
      interactions: m.interactions,
    })),
    notes,
    partner,
    styleHint: options.styleHint,
  };
}

// 오행 상생: 목→화→토→금→수→목 / 상극: 목→토, 토→수, 수→화, 화→금, 금→목
const GENERATES: Record<keyof FiveElementBalance, keyof FiveElementBalance> = {
  wood: "fire", fire: "earth", earth: "metal", metal: "water", water: "wood",
};
const OVERCOMES: Record<keyof FiveElementBalance, keyof FiveElementBalance> = {
  wood: "earth", earth: "water", water: "fire", fire: "metal", metal: "wood",
};

/** 내 원국과 상대방 원국을 대조해 관계 근거를 만든다 */
function buildPartnerEvidence(myChart: SajuChart, partnerBirth: BirthInfo): PartnerEvidence {
  const pChart = computeSajuChart(partnerBirth);
  const myGan = myChart.dayMasterGan;
  const pGan = pChart.dayMasterGan;
  const myEl = elementOfGan(myGan);
  const pEl = elementOfGan(pGan);

  let elementRelation: PartnerEvidence["elementRelation"];
  if (myEl === pEl) elementRelation = "비화";
  else if (GENERATES[pEl] === myEl) elementRelation = "생함"; // 상대가 나를 생함
  else if (GENERATES[myEl] === pEl) elementRelation = "생받음"; // 상대는 나에게서 생받음
  else if (OVERCOMES[pEl] === myEl) elementRelation = "극함"; // 상대가 나를 극함
  else elementRelation = "극받음";

  // 두 원국 지지 사이의 합/충 등
  const myZhis = [myChart.year.zhi, myChart.month.zhi, myChart.day.zhi, ...(myChart.hour ? [myChart.hour.zhi] : [])];
  const pZhis = [pChart.year.zhi, pChart.month.zhi, pChart.day.zhi, ...(pChart.hour ? [pChart.hour.zhi] : [])];
  const branchHits: string[] = [];
  for (const mz of myZhis) {
    for (const pz of pZhis) {
      const rel = branchRelationsBetween(mz, pz);
      if (rel.length > 0) branchHits.push(`내 ${mz} ↔ 상대 ${pz}: ${rel.join("·")}`);
    }
  }

  const notes: string[] = [
    `상대 일간: ${pGan} (${ELEMENT_KO[pEl]})`,
    `오행 관계: 상대가 나를 ${elementRelation}`,
    `내가 상대를 보는 십성: ${tenGodOf(myGan, pGan)}`,
    `상대가 나를 보는 십성: ${tenGodOf(pGan, myGan)}`,
  ];
  if (branchHits.length > 0) notes.push(`지지 관계: ${branchHits.slice(0, 3).join(" / ")}`);
  else notes.push("두 사주 지지에 뚜렷한 합충 없음(무난·자극 적음)");

  return {
    dayMaster: pGan,
    dayMasterElement: ELEMENT_KO[pEl],
    myTenGodToPartner: tenGodOf(myGan, pGan),
    partnerTenGodToMe: tenGodOf(pGan, myGan),
    elementRelation,
    branchHits,
    notes,
  };
}

/** 관심사 → 한글 라벨 */
export const INTEREST_LABEL: Record<ReadingInterest, string> = {
  work: "일/직업",
  money: "돈/재물",
  love: "연애",
  marriage: "결혼",
  relationship: "인간관계",
  family: "가족",
  health: "건강/컨디션",
  future: "미래 불안",
  selfWorth: "자존감",
  all: "전체 보기",
};

function elementOfGan(gan: string): keyof FiveElementBalance {
  return GAN_WUXING[gan] ?? "earth";
}
