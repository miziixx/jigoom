// 사주 계산 근거 데이터 조립. 계산은 전부 기존 엔진(src/lib)을 재사용하고,
// Claude에는 "이 데이터 안에서만 해석하라"는 근거 팩으로 전달한다.
import { computeSajuChart, computeLuckCycles } from "../src/lib/saju.js";
import { computeFortuneEvidence } from "../src/lib/fortune.js";
import type { BirthInfo, LuckCycles, SajuChart } from "../src/types/index.js";
import { describeBirthInfo } from "./parseBirth.js";

export interface ComputedPack {
  chart: SajuChart;
  luck: LuckCycles;
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
  return [
    `[출생 정보] ${describeBirthInfo(birthInfo)}`,
    "",
    "[원국 계산 데이터 — 만세력 기반으로 프로그램이 정확히 계산한 값]",
    JSON.stringify(chart),
    "",
    "[운의 흐름 계산 데이터 — 대운/올해 세운/월운]",
    JSON.stringify(luck),
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
