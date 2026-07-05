import type { ReadingType } from "../types/index.js";
import { validateOutputAgainstJudgmentPack } from "./judgmentValidation.js";
import type { JudgmentPack } from "./judgmentTypes.js";

export type ReadingValidationIssueCode =
  | "missing-section"
  | "deterministic-claim"
  | "excessive-jargon"
  | "generic-advice"
  | "judgment-gate";

export interface ReadingValidationIssue {
  code: ReadingValidationIssueCode;
  message: string;
  severity: "warning" | "error";
  evidence?: string;
}

export interface ReadingValidationResult {
  ok: boolean;
  issues: ReadingValidationIssue[];
  warningText: string | null;
}

const REQUIRED_SECTIONS = ["# 첫 점괘", "# 분야별 요약", "# 지금 해야 할 것과 피해야 할 것", "# 마지막 점괘"];
const QUESTION_SECTION = "# 질문 중심 핵심";

const DETERMINISTIC_PATTERNS = [
  /반드시\s*(성공|실패|헤어|이혼|합격|불합격|망|파산|병|사고)/,
  /무조건\s*(해야|된다|좋다|나쁘다|성공|실패|헤어|이혼)/,
  /100%\s*(된다|성공|실패|확실)/,
  /절대\s*(하면 안|하지 마|안 된다|된다)/,
  /곧\s*(죽|망|파산|큰 사고|큰 병)/,
];

const JARGON_TERMS = [
  "일간",
  "월지",
  "천간",
  "지지",
  "간지",
  "오행",
  "비견",
  "겁재",
  "식신",
  "상관",
  "편재",
  "정재",
  "편관",
  "정관",
  "편인",
  "정인",
  "인성",
  "식상",
  "재성",
  "관성",
  "비겁",
  "합",
  "충",
  "형",
  "파",
  "해",
  "삼합",
  "육합",
  "방합",
  "공망",
  "신살",
  "용신",
  "희신",
  "기신",
  "대운",
  "세운",
  "월운",
  "신강",
  "신약",
  "격국",
];

const GENERIC_SENTENCES = [
  "신중하게 결정하세요",
  "무리하지 마세요",
  "새로운 변화를 준비하세요",
  "주변 사람과의 갈등을 조심하세요",
  "긍정적인 마음을 가지세요",
  "자신을 믿으세요",
];

function countOccurrences(text: string, terms: string[]): number {
  return terms.reduce((sum, term) => sum + text.split(term).length - 1, 0);
}

function missingSections(text: string, hasQuestion: boolean): string[] {
  const sections = hasQuestion ? [...REQUIRED_SECTIONS, QUESTION_SECTION] : REQUIRED_SECTIONS;
  return sections.filter((section) => !text.includes(section));
}

export function validateReadingOutput(params: {
  type: ReadingType;
  question?: string;
  reply: string;
  judgmentPack?: JudgmentPack | null;
}): ReadingValidationResult {
  const { type, question = "", reply, judgmentPack } = params;
  if (type !== "saju" && type !== "combo") return { ok: true, issues: [], warningText: null };

  const issues: ReadingValidationIssue[] = [];
  for (const section of missingSections(reply, question.trim().length > 0)) {
    issues.push({
      code: "missing-section",
      severity: "error",
      message: `필수 섹션이 누락되었습니다: ${section}`,
      evidence: section,
    });
  }

  for (const pattern of DETERMINISTIC_PATTERNS) {
    const hit = reply.match(pattern)?.[0];
    if (hit) {
      issues.push({
        code: "deterministic-claim",
        severity: "error",
        message: "근거 밖 단정 또는 고위험 예언처럼 보이는 문장이 있습니다.",
        evidence: hit,
      });
      break;
    }
  }

  const expertEvidenceText = reply
    .split("[전문가 근거 보기]")
    .slice(1)
    .join("\n");
  const surfaceText = reply.replace(expertEvidenceText, "");
  const jargonCount = countOccurrences(surfaceText, JARGON_TERMS);
  if (jargonCount >= 8) {
    issues.push({
      code: "excessive-jargon",
      severity: "warning",
      message: "본문에 사주 전문용어가 많이 남아 있습니다.",
      evidence: `${jargonCount}회`,
    });
  }

  const genericHits = GENERIC_SENTENCES.filter((sentence) => reply.includes(sentence));
  if (genericHits.length > 0) {
    issues.push({
      code: "generic-advice",
      severity: "warning",
      message: "너무 일반적인 조언 문장이 남아 있습니다.",
      evidence: genericHits.join(", "),
    });
  }

  if (judgmentPack) {
    const gate = validateOutputAgainstJudgmentPack({ reply, pack: judgmentPack });
    for (const issue of gate.issues) {
      issues.push({
        code: "judgment-gate",
        severity: issue.severity,
        message: issue.message,
        evidence: issue.evidence,
      });
    }
  }

  const ok = issues.every((issue) => issue.severity !== "error");
  const warningText =
    issues.length > 0
      ? [
          "",
          "# 검수 메모",
          "이번 리딩은 자동 검수에서 아래 항목을 확인했습니다. 내용은 참고용으로 읽고, 중요한 결정은 현실 정보와 함께 판단해주세요.",
          ...issues.map((issue) => `- ${issue.message}${issue.evidence ? ` (${issue.evidence})` : ""}`),
        ].join("\n")
      : null;

  return { ok, issues, warningText };
}

export function applyReadingValidationWarning(params: {
  type: ReadingType;
  question?: string;
  reply: string;
  judgmentPack?: JudgmentPack | null;
}): { reply: string; validation: ReadingValidationResult } {
  const validation = validateReadingOutput(params);
  if (!validation.warningText || params.reply.includes("# 검수 메모")) return { reply: params.reply, validation };
  return { reply: `${params.reply.trimEnd()}\n\n${validation.warningText}`, validation };
}
