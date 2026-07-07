// 사용자 질문에서 길이 제어 힌트(짧게, 자세히 등)를 감지하고 추출합니다.

const BRIEF_PATTERNS = ["짧게", "간단히", "요약", "핵심만", "간단해", "간단할", "줄여서", "간단하게"];
const DETAILED_PATTERNS = ["길게", "자세히", "깊게", "전부", "완벽하게", "자세하게", "상세하게", "모두"];
const NORMAL_PATTERNS = ["일반", "보통", "정상", "다시", "원래"];

export interface VerbosityHint {
  override?: "brief" | "normal" | "detailed";
  cleanQuestion: string;
}

/** 질문에서 길이 제어 힌트를 추출하고 질문을 정리합니다 */
export function extractVerbosityHint(question: string): VerbosityHint {
  const original = question.trim();
  let override: "brief" | "normal" | "detailed" | undefined;
  let cleanQuestion = original;

  // 더 긴 패턴부터 체크 (예: "간단하게"를 먼저 매치해야 "간단"과 혼동하지 않음)
  const sortedBrief = [...BRIEF_PATTERNS].sort((a, b) => b.length - a.length);
  const sortedDetailed = [...DETAILED_PATTERNS].sort((a, b) => b.length - a.length);

  // brief 체크
  for (const pattern of sortedBrief) {
    if (original.includes(pattern)) {
      override = "brief";
      cleanQuestion = original.replace(new RegExp(`\\s*${pattern}\\s*`, "g"), " ").trim();
      break;
    }
  }

  // 이미 발견했으면 스킵, 아니면 detailed 체크
  if (!override) {
    for (const pattern of sortedDetailed) {
      if (original.includes(pattern)) {
        override = "detailed";
        cleanQuestion = original.replace(new RegExp(`\\s*${pattern}\\s*`, "g"), " ").trim();
        break;
      }
    }
  }

  // 아직도 발견 안 했으면 normal 체크
  if (!override) {
    for (const pattern of NORMAL_PATTERNS) {
      if (original.includes(pattern)) {
        override = "normal";
        cleanQuestion = original.replace(new RegExp(`\\s*${pattern}\\s*`, "g"), " ").trim();
        break;
      }
    }
  }

  return { override, cleanQuestion };
}
