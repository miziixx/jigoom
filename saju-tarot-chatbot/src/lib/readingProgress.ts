import type { AnswerDepth, ReadingType } from "../types/index.js";

/**
 * 리딩 타입별 기대 섹션 제목(순서대로). `# 질문 중심 핵심`은 질문이 있을 때만 별도로 끼워 넣는다.
 * 이 목록은 서버 전용 `api/reading.ts`/`src/prompts/systemPrompt.ts`의 [출력 형식] 지시와
 * 동기화되어야 한다(systemPrompt.ts는 서버 전용이라 클라이언트 번들에 직접 import할 수 없다).
 */
const BASE_SECTIONS: Record<ReadingType, string[]> = {
  saju: [
    "첫 점괘",
    "분야별 요약",
    "타고난 성격과 기질",
    "직업과 돈",
    "재물 흐름",
    "애정과 관계",
    "건강과 컨디션",
    "인생의 큰 흐름",
    "올해의 흐름",
    "지금 해야 할 것과 피해야 할 것",
    "마지막 점괘",
  ],
  combo: [
    "첫 점괘",
    "사주로 보는 장기 흐름",
    "타로로 보는 현재 흐름",
    "통합 판단",
    "분야별 요약",
    "타고난 성격과 기질",
    "직업과 돈",
    "재물 흐름",
    "애정과 관계",
    "건강과 컨디션",
    "인생의 큰 흐름",
    "올해의 흐름",
    "지금 해야 할 것과 피해야 할 것",
    "마지막 점괘",
  ],
  tarot: ["첫 점괘", "카드가 그리는 흐름", "지금 해야 할 것과 피해야 할 것", "마지막 점괘"],
  today: ["첫 점괘", "올해의 흐름", "지금 해야 할 것과 피해야 할 것", "마지막 점괘"],
  flow: ["첫 점괘", "올해의 흐름", "인생의 큰 흐름", "지금 해야 할 것과 피해야 할 것", "마지막 점괘"],
};

/**
 * 고급(advanced) 깊이에서 saju/combo에 추가되는 섹션(systemPrompt.ts DEPTH_INSTRUCTION.advanced와
 * 동기화). "지금 해야 할 것과 피해야 할 것" 바로 앞에 끼워 넣는다. B-3: 이 목록이 없으면 평생사주
 * 리포트의 진행률 total이 실제보다 3개 적게 잡혀 100%가 너무 일찍 뜨는 버그가 있었다.
 */
const ADVANCED_EXTRA_SECTIONS = ["반복 패턴 정밀 진단", "선택과 시기 판단", "3개월 실행 전략"];

function expectedSections(type: ReadingType, hasQuestion: boolean, depth?: AnswerDepth): string[] {
  const expected = [...BASE_SECTIONS[type]];
  if (hasQuestion) expected.splice(1, 0, "질문 중심 핵심");
  if (depth === "advanced" && (type === "saju" || type === "combo")) {
    const actionIdx = expected.indexOf("지금 해야 할 것과 피해야 할 것");
    expected.splice(actionIdx, 0, ...ADVANCED_EXTRA_SECTIONS);
  }
  return expected;
}

export interface ReadingProgress {
  completed: number;
  total: number;
  percent: number;
  /** 다음에 쓰일 것으로 예상되는 섹션. 이미 다 나왔으면 null. */
  currentTitle: string | null;
}

/**
 * 실시간 스트리밍 중인 답변 텍스트(`replyText`)에 지금까지 등장한 `# 섹션명` 헤더를 보고
 * 진짜 진행률을 계산한다. `today` 타입처럼 헤더에 괄호가 붙는 경우를 위해 접두어 일치로 판정하고,
 * 조건부 섹션(질문 중심 핵심)이 스킵돼도 뒤 섹션이 등장하면 진행률이 계속 올라가도록
 * "지금까지 발견된 것 중 가장 뒤에 있는 섹션"을 기준으로 삼는다(순서 강제 매칭이 아님).
 */
export function buildReadingProgress(type: ReadingType, hasQuestion: boolean, replyText: string, depth?: AnswerDepth): ReadingProgress {
  const expected = expectedSections(type, hasQuestion, depth);
  const headers = [...replyText.matchAll(/^#\s+(.+)$/gm)].map((m) => m[1].trim());

  let lastFoundIndex = -1;
  expected.forEach((title, idx) => {
    if (headers.some((h) => h.startsWith(title))) lastFoundIndex = idx;
  });

  const total = expected.length;
  const completed = lastFoundIndex + 1;
  const percent = total > 0 ? Math.round((completed / total) * 100) : 0;
  const currentTitle = completed < total ? expected[completed] : null;

  return { completed, total, percent, currentTitle };
}

export interface ReadingSectionStatus {
  title: string;
  status: "done" | "writing" | "waiting";
}

/**
 * 리포트 진행 화면(B-3, 시안 ③)용: 섹션별 상태 목록. buildReadingProgress와 같은 "가장 뒤에서
 * 발견된 섹션까지 완료" 판정을 재사용해, 조건부 섹션이 스킵돼도 목록이 헛갈리지 않게 한다.
 */
export function buildReadingSectionStatuses(
  type: ReadingType,
  hasQuestion: boolean,
  replyText: string,
  depth?: AnswerDepth,
): ReadingSectionStatus[] {
  const expected = expectedSections(type, hasQuestion, depth);
  const headers = [...replyText.matchAll(/^#\s+(.+)$/gm)].map((m) => m[1].trim());

  let lastFoundIndex = -1;
  expected.forEach((title, idx) => {
    if (headers.some((h) => h.startsWith(title))) lastFoundIndex = idx;
  });

  return expected.map((title, idx) => ({
    title,
    status: idx < lastFoundIndex ? "done" : idx === lastFoundIndex ? "writing" : "waiting",
  }));
}
