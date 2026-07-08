// 사주/점성술 계산 결과 + 감지된 의도 + 저장된 기억을 하나의 압축된 assistantContext로 묶는다.
// 이건 새로 만드는 비서 모드(기획/글쓰기/판단/자기분석) 전용이다 — 기존 askTeacher()의
// 사주 대화 흐름(원국 JSON 통째 전달)은 건드리지 않는다.
// Claude는 여기 담긴 계산 결과만 근거로 받고, 생년월일 원본이나 좌표 계산 자체는 절대 하지 않는다.
import { computePack, type ChartSource } from "./evidence.js";
import { buildAstrologySummary, type AstrologySummary } from "./astrologyEvidence.js";
import type { DetectedIntent } from "./intentDetector.js";
import type { MemoryEntry } from "./storeTypes.js";
import type { BirthInfo } from "../src/types/index.js";

export interface SajuSummary {
  fourPillars: string;
  dayMaster: string;
  fiveElementsBalance: string;
  tenGodsSummary: string;
  currentYearFlow: string;
  cautionPoints: string[];
}

export interface AssistantContext {
  sajuSummary: SajuSummary | null;
  astrologySummary: AstrologySummary | null;
  detectedIntent: DetectedIntent;
  savedMemorySummary: string[];
  currentQuestionSummary: string;
  securityLevel: "normal" | "sensitive" | "highlySensitive";
}

/** 기존 evidence.ts의 원국 계산 결과를 스펙이 요구하는 압축 사주 요약으로 정리한다. */
export function buildSajuSummary(source: ChartSource): SajuSummary {
  const { chart, luck } = computePack(source);

  const fourPillars = [chart.year.ganZhi, chart.month.ganZhi, chart.day.ganZhi, chart.hour?.ganZhi ?? "시주 모름"].join(" ");
  const fe = chart.fiveElements;
  const fiveElementsBalance = `목${fe.wood} 화${fe.fire} 토${fe.earth} 금${fe.metal} 수${fe.water}`;
  const tenGodsSummary = chart.tenGods.join("·") || "계산 정보 없음";

  const currentDaYun = luck.daYun.find((d) => d.current);
  const currentYearFlow = [
    `올해 세운 ${luck.yearGanZhi}`,
    currentDaYun ? `현재 대운 ${currentDaYun.ganZhi}(${currentDaYun.startAge}~${currentDaYun.endAge}세)` : "대운 정보 없음(팔자만 입력)",
  ].join(", ");

  const cautionPoints: string[] = [];
  if (chart.strength?.label === "신약") cautionPoints.push("일간이 약한 편 — 무리한 확장보다 기반 다지기 우선");
  if (chart.strength?.label === "신강") cautionPoints.push("일간이 강한 편 — 밀어붙이기보다 속도 조절 필요할 수 있음");
  if (chart.yongshin?.unfavorable && chart.yongshin.unfavorable.length > 0) {
    cautionPoints.push(`부담 기운(기신 후보): ${chart.yongshin.unfavorable.join("·")}`);
  }
  if (chart.sinsal && chart.sinsal.length > 0) {
    const names = [...new Set(chart.sinsal.map((s) => s.name))].slice(0, 5);
    cautionPoints.push(`참고 신살: ${names.join(", ")}`);
  }

  return { fourPillars, dayMaster: chart.dayMasterGan, fiveElementsBalance, tenGodsSummary, currentYearFlow, cautionPoints };
}

const SENSITIVE_KEYWORDS = ["이혼", "이별", "퇴사", "이직", "빚", "파산", "소송", "질병", "건강", "우울", "불안", "연애", "결혼"];
const HIGH_SENSITIVE_KEYWORDS = ["자살", "죽고\\s*싶", "극단적", "자해"];

/** 기억 저장 시 sensitive 플래그 판정 등에도 재사용하는 민감 텍스트 여부 판정. */
export function isSensitiveContent(text: string): boolean {
  return SENSITIVE_KEYWORDS.some((k) => text.includes(k)) || HIGH_SENSITIVE_KEYWORDS.some((k) => new RegExp(k).test(text));
}

function detectSecurityLevel(question: string): AssistantContext["securityLevel"] {
  if (HIGH_SENSITIVE_KEYWORDS.some((k) => new RegExp(k).test(question))) return "highlySensitive";
  if (SENSITIVE_KEYWORDS.some((k) => question.includes(k))) return "sensitive";
  return "normal";
}

export interface BuildAssistantContextInput {
  chartSource: ChartSource | null;
  birthInfo: BirthInfo | null;
  detectedIntent: DetectedIntent;
  memories: MemoryEntry[];
  currentQuestion: string;
}

export function buildAssistantContext({
  chartSource,
  birthInfo,
  detectedIntent,
  memories,
  currentQuestion,
}: BuildAssistantContextInput): AssistantContext {
  const sajuSummary = chartSource ? buildSajuSummary(chartSource) : null;
  // 점성술은 생년월일시(BirthInfo)가 있어야 계산 가능 — 사주팔자 직접입력만 등록한 경우 제외.
  const astrologySummary = birthInfo ? buildAstrologySummary(birthInfo) : null;

  return {
    sajuSummary,
    astrologySummary,
    detectedIntent,
    savedMemorySummary: memories.map((m) => `[${m.category}] ${m.summary}`),
    currentQuestionSummary: currentQuestion.slice(0, 300),
    securityLevel: detectSecurityLevel(currentQuestion),
  };
}
