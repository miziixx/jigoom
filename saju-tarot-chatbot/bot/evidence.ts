// 사주 계산 근거 데이터 조립. 계산은 전부 기존 엔진(src/lib)을 재사용하고,
// Claude에는 "이 데이터 안에서만 해석하라"는 근거 팩으로 전달한다.
import { computeSajuChart, computeLuckCycles, computeCompatibility } from "../src/lib/saju.js";
import { computeFortuneEvidence } from "../src/lib/fortune.js";
import type { BirthInfo, CompatibilityRelationType, LuckCycles, SajuChart } from "../src/types/index.js";
import { describeBirthInfo } from "./parseBirth.js";

export interface ComputedPack {
  chart: SajuChart;
  luck: LuckCycles;
}

// ── 입고/개고 (묘고) ──────────────────────────────────────────
// 진술축미(土)는 각각 한 오행의 창고(墓庫). 창고에 든 기운은 갇혀 있다가(입고)
// 충으로 창고가 열리면(개고) 그 기운이 튀어나온다. 표준 묘고 이론 기준.
// 지장간 중기가 그 창고의 대표 기운이다(진: 계水, 술: 정火, 축: 신金, 미: 을木).
const STORAGE_BRANCH: Record<string, { elementKo: string; buriedGan: string }> = {
  진: { elementKo: "수(水)", buriedGan: "계" },
  술: { elementKo: "화(火)", buriedGan: "정" },
  축: { elementKo: "금(金)", buriedGan: "신" },
  미: { elementKo: "목(木)", buriedGan: "을" },
};
// 개고를 일으키는 충 쌍 (진술충 / 축미충)
const STORAGE_CHONG: Record<string, string> = { 진: "술", 술: "진", 축: "미", 미: "축" };

export interface StorageHit {
  position: string; // 예: "월지"
  branch: string; // 진/술/축/미
  stores: string; // "수(水) 창고 (계水 갇힘)"
  openedByNatalChong: boolean; // 원국 안에 충 상대 지지가 있어 이미 열려 있는지
}

/** 원국의 창고(묘고) 지지와 개고 여부를 계산한다. 판단은 원국 지지만 근거로 한다. */
export function computeStorageStatus(chart: SajuChart): StorageHit[] {
  const positioned: Array<{ pos: string; zhi: string }> = [
    { pos: "연지", zhi: chart.year.zhi },
    { pos: "월지", zhi: chart.month.zhi },
    { pos: "일지", zhi: chart.day.zhi },
    ...(chart.hour ? [{ pos: "시지", zhi: chart.hour.zhi }] : []),
  ];
  const branchSet = new Set(positioned.map((p) => p.zhi));
  const hits: StorageHit[] = [];
  for (const { pos, zhi } of positioned) {
    const info = STORAGE_BRANCH[zhi];
    if (!info) continue;
    hits.push({
      position: pos,
      branch: zhi,
      stores: `${info.elementKo} 창고 (${info.buriedGan}${info.elementKo[0]} 갇힘)`,
      openedByNatalChong: branchSet.has(STORAGE_CHONG[zhi]),
    });
  }
  return hits;
}

/**
 * 로컬 getter가 KST 벽시계 값을 돌려주는 Date를 만든다.
 * computeLuckCycles는 now의 로컬 필드(Solar.fromDate)를 쓰므로, UTC 등 다른 시간대
 * 서버에서 봇을 돌려도 세운/월운/일진이 한국 날짜 기준으로 계산되게 한다.
 */
function kstNow(): Date {
  const shifted = new Date(Date.now() + 9 * 60 * 60 * 1000);
  return new Date(
    shifted.getUTCFullYear(),
    shifted.getUTCMonth(),
    shifted.getUTCDate(),
    shifted.getUTCHours(),
    shifted.getUTCMinutes(),
    shifted.getUTCSeconds(),
  );
}

export function computePack(birthInfo: BirthInfo): ComputedPack {
  const chart = computeSajuChart(birthInfo);
  const luck = computeLuckCycles(birthInfo, kstNow(), {
    includeMonthlyFlow: true,
    yongElements: chart.yongshin?.supportive,
    avoidElements: chart.yongshin?.unfavorable,
  });
  return { chart, luck };
}

/** 원국·대운 근거 (사용자마다 고정, 대화 첫 컨텍스트로 전달) */
export function buildNatalEvidence(birthInfo: BirthInfo): string {
  const { chart, luck } = computePack(birthInfo);
  const storage = computeStorageStatus(chart);
  return [
    `[출생 정보] ${describeBirthInfo(birthInfo)}`,
    "",
    "[원국 계산 데이터 — 만세력 기반으로 프로그램이 정확히 계산한 값]",
    JSON.stringify(chart),
    "",
    "[입고/개고(묘고) 계산 데이터 — 원국의 창고 지지와 개고(충으로 열림) 여부]",
    storage.length > 0 ? JSON.stringify(storage) : "원국에 창고(진술축미) 지지 없음",
    "",
    "[운의 흐름 계산 데이터 — 대운/올해 세운/월운]",
    JSON.stringify(luck),
  ].join("\n");
}

const RELATION_LABEL: Record<CompatibilityRelationType, string> = {
  romantic: "연인·배우자",
  parentChild: "부모·자식",
  siblings: "형제·자매",
  family: "가족",
  bossEmployee: "직장 상사·직원",
  coworker: "동료·동업자",
  friend: "친구",
  rival: "라이벌·불편한 관계",
};

/** 궁합 근거 (나 + 상대 + 관계 유형). computeCompatibility 결과 전체를 근거로 전달한다. */
export function buildCompatibilityEvidence(
  myBirth: BirthInfo,
  otherBirth: BirthInfo,
  relationType: CompatibilityRelationType,
): string {
  const result = computeCompatibility(myBirth, otherBirth, relationType, undefined, { first: "나", second: "상대" });
  return [
    `[궁합 대상] 관계 유형: ${RELATION_LABEL[relationType]}`,
    `- 나: ${describeBirthInfo(myBirth)}`,
    `- 상대: ${describeBirthInfo(otherBirth)}`,
    "",
    "[궁합 계산 데이터 — 두 원국의 일간 관계·지지 합충·오행 보완·일지(배우자궁)·역할 궁합·점수를 프로그램이 계산한 값]",
    JSON.stringify(result),
  ].join("\n");
}

/** 오늘 일진 근거 (매 질문마다 새로 계산해 현재 턴에만 첨부) */
export function buildTodayEvidence(birthInfo: BirthInfo): string {
  const fortune = computeFortuneEvidence(birthInfo);
  return [
    `[오늘(${fortune.date} ${fortune.weekday}) 일진 계산 데이터 — 오늘 간지와 내 원국의 상호작용]`,
    JSON.stringify(fortune),
  ].join("\n");
}

/** API 호출 없이 즉시 보여주는 원국 요약 (/saju 명령) */
export function formatChartSummary(birthInfo: BirthInfo): string {
  const { chart, luck } = computePack(birthInfo);
  const lines: string[] = [];

  lines.push("📜 *내 사주 원국*");
  lines.push(`연주 ${chart.year.ganZhi} · 월주 ${chart.month.ganZhi} · 일주 ${chart.day.ganZhi} · 시주 ${chart.hour?.ganZhi ?? "모름"}`);
  lines.push(`일간(나): ${chart.dayMasterGan}`);
  lines.push("");

  const fe = chart.fiveElements;
  lines.push(`오행 분포 — 목 ${fe.wood} · 화 ${fe.fire} · 토 ${fe.earth} · 금 ${fe.metal} · 수 ${fe.water}`);
  if (chart.strength) {
    lines.push(`신강/신약: *${chart.strength.label}* (${chart.strength.detail})`);
  }
  if (chart.gyeokguk) {
    lines.push(`격국: ${chart.gyeokguk.name} — ${chart.gyeokguk.gloss}`);
  }
  if (chart.yongshin) {
    const yong = chart.yongshin.yongshin ?? chart.yongshin.supportive;
    lines.push(`보완하면 좋은 기운(용신 후보): ${yong.join("·") || "-"} / 부담 기운: ${chart.yongshin.unfavorable.join("·") || "-"}`);
  }
  if (chart.interactions && chart.interactions.length > 0) {
    lines.push(`합충형파해: ${chart.interactions.join(", ")}`);
  }
  if (chart.sinsal && chart.sinsal.length > 0) {
    const names = [...new Set(chart.sinsal.map((s) => s.name))].slice(0, 12);
    lines.push(`신살: ${names.join(", ")}`);
  }

  const current = luck.daYun.find((d) => d.current);
  if (current) {
    lines.push("");
    lines.push(`현재 대운: ${current.ganZhi} (${current.startAge}~${current.endAge}세, ${current.startYear}~${current.endYear}년)`);
  }
  lines.push(`올해 세운: ${luck.yearGanZhi} · 이번 달: ${luck.monthGanZhi} · 오늘 일진: ${luck.dayGanZhi ?? "-"}`);

  lines.push("");
  lines.push("궁금한 건 그냥 물어보세요. 예: \"나 왜 신약사주야?\", \"오늘 일진이 왜 이렇게 흘러가?\"");
  return lines.join("\n");
}
