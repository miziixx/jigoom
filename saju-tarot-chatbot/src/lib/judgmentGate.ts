import { formatJudgmentPackForPrompt } from "./judgmentPrompt.js";
import { validateOutputAgainstJudgmentPack, type JudgmentValidationResult } from "./judgmentValidation.js";
import type { JudgmentCandidate, JudgmentPack } from "./judgmentTypes.js";

export interface JudgmentGatePass {
  status: "pass";
  reply: string;
  validation: JudgmentValidationResult;
  rewriteAttempted: false;
  fallbackUsed: false;
}

export interface JudgmentGateRewrite {
  status: "rewrite";
  reply: string;
  validation: JudgmentValidationResult;
  firstValidation: JudgmentValidationResult;
  rewriteAttempted: true;
  fallbackUsed: false;
}

export interface JudgmentGateFallback {
  status: "fallback";
  reply: string;
  validation: JudgmentValidationResult;
  firstValidation: JudgmentValidationResult;
  rewriteValidation?: JudgmentValidationResult;
  rewriteAttempted: true;
  fallbackUsed: true;
}

export type JudgmentGateResult = JudgmentGatePass | JudgmentGateRewrite | JudgmentGateFallback;

export function buildJudgmentRewritePrompt(params: {
  originalReply: string;
  validation: JudgmentValidationResult;
  pack: JudgmentPack;
}): string {
  return [
    "[Rewrite 요청]",
    "아래 응답은 Evidence Gate 검증에 실패했다. 같은 JudgmentPack만 사용해 안전한 최종 답변으로 다시 작성하라.",
    "",
    "규칙:",
    "- JudgmentPack에 없는 새 결론을 추가하지 마라.",
    "- forbiddenClaims, semantic violation, confidence tone violation에 걸린 문장은 제거하라.",
    "- confidence < 40은 '가능성/여지/단정하기 어렵다'로만 표현하라.",
    "- confidence 40~70은 '경향/흐름/조건'으로 표현하라.",
    "- confidence > 70이어도 '반드시/무조건/100%/절대'는 쓰지 마라.",
    "- 행동 조언은 judgments[].actionFrame 안에서만 작성하라.",
    "- 출력은 사용자에게 보낼 최종 리딩 본문만 작성하라.",
    "",
    "[검증 실패 항목]",
    ...params.validation.issues.map((issue) => `- ${issue.severity}: ${issue.message}${issue.evidence ? ` (${issue.evidence})` : ""}`),
    "",
    "[JudgmentPack]",
    formatJudgmentPackForPrompt(params.pack),
    "",
    "[기존 응답]",
    params.originalReply,
  ].join("\n");
}

export function buildJudgmentFallback(pack: JudgmentPack): string {
  const judgments = pack.judgments.slice(0, 5);
  const lines = judgments.flatMap((judgment) => fallbackLinesForJudgment(judgment));
  return [
    "# 첫 점괘",
    "현재 계산 근거만으로는 단정적인 결론을 내리기 어렵습니다. 근거가 충분한 범위만 안전하게 안내드립니다.",
    "",
    "# 분야별 요약",
    ...lines,
    "",
    "# 질문 중심 핵심",
    "질문에 대한 답은 계산 근거가 허용하는 범위 안에서만 조건부로 봅니다. 큰 결정을 바로 확정하기보다 준비 조건을 먼저 확인하는 쪽이 안전합니다.",
    "",
    "# 지금 해야 할 것과 피해야 할 것",
    "- 해야 할 것: 현실 조건, 일정, 비용, 반복 신호를 먼저 확인하세요.",
    "- 피해야 할 것: 퇴사, 투자, 창업, 결혼, 건강 진단처럼 되돌리기 어려운 결정을 한 문장으로 확정하지 마세요.",
    "",
    "# 마지막 점괘",
    "이번 흐름은 결론을 크게 단정하기보다, 확인된 신호 안에서 작은 선택 기준을 세우는 쪽이 안전합니다.",
  ].join("\n");
}

export function finalizeJudgmentPackAudit(pack: JudgmentPack, result: JudgmentGateResult): JudgmentPack {
  const finalConfidence = pack.judgments.length
    ? Math.round(pack.judgments.reduce((sum, judgment) => sum + judgment.confidence.overall, 0) / pack.judgments.length)
    : 0;
  return {
    ...pack,
    audit: {
      ...pack.audit,
      validationStatus: result.status,
      validationIssueIds: result.validation.issues.map((issue) => issue.code),
      rewriteAttempted: result.rewriteAttempted,
      fallbackUsed: result.fallbackUsed,
      finalConfidence,
    },
    decisionTrace: [
      ...pack.decisionTrace,
      {
        stage: "validation",
        refId: `validation.${result.status}`,
        summary: `Evidence Gate 최종 상태: ${result.status}`,
      },
    ],
  };
}

export function passOrNeedsRewrite(reply: string, pack: JudgmentPack): JudgmentGatePass | { status: "needs-rewrite"; validation: JudgmentValidationResult } {
  const validation = validateOutputAgainstJudgmentPack({ reply, pack });
  if (validation.ok) {
    return {
      status: "pass",
      reply,
      validation,
      rewriteAttempted: false,
      fallbackUsed: false,
    };
  }
  return { status: "needs-rewrite", validation };
}

function fallbackLinesForJudgment(judgment: JudgmentCandidate): string[] {
  const confidenceWord = judgment.confidence.overall < 40 ? "가능성" : judgment.confidence.overall <= 70 ? "경향" : "흐름";
  const action = judgment.actionFrame.do[0] ?? "현실 조건을 먼저 확인하세요.";
  const caution = judgment.actionFrame.avoid[0] ?? "단정적인 실행 결론은 피하세요.";
  return [
    `- ${judgment.domain}: ${judgment.plainConclusion}`,
    `  근거 강도는 ${judgment.confidence.overall}% 수준이므로 '${confidenceWord}'으로만 봅니다.`,
    `  권장: ${action}`,
    `  주의: ${caution}`,
  ];
}
