import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import ReadingResult from "./ReadingResult.js";
import { computeLuckCycles, computeSajuChart } from "../lib/saju.js";
import type { BirthInfo, ReadingSession } from "../types/index.js";

// 새 몰입 구조 + 마크다운/사주용어가 섞인 모델 응답 (렌더 시 정리되어야 함)
const REPLY = [
  "# 첫 점괘",
  "지금은 **쉬고 싶은 게 아니라**, 방향을 잃어서 지친 상태에 가깝습니다.",
  "",
  "# 분야별 요약",
  "- 직업·재물: 평가 보통 — 방향이 잡히면 성과가 붙는 흐름이에요.",
  "- 애정·관계: 평가 주의 — 기대를 눌러두다 한 번에 식기 쉬워요.",
  "- 건강·컨디션: 평가 주의 — 생각이 많아 몸이 먼저 지쳐요.",
  "- 멘탈·감정: 평가 좋음 — 스스로를 돌아보는 힘이 살아나요.",
  "",
  "# 건강과 컨디션",
  "요즘은 초조함이 올라오기 쉬운 시기예요. 다음을 특히 살펴보세요:",
  "- 잠들기 전 생각이 길어지는 편",
  "- 쉬어도 개운하지 않은 느낌",
  "",
  "# 마지막 점괘",
  "지금은 더 밀어붙이는 시기가 아니라, 나를 갉아먹는 것을 끊어내는 시기입니다.",
].join("\n");

function makeSession(reply: string): ReadingSession {
  return {
    id: "t1",
    type: "saju",
    createdAt: "2026-07-03T03:00:00.000Z",
    question: "요즘 너무 지쳐요",
    messages: [
      { role: "user", content: "..." },
      { role: "assistant", content: reply },
    ],
  };
}

const JARGON = [
  "일간", "월지", "천간", "지지", "오행", "십성", "비겁", "식상", "재성", "관성", "인성",
  "편관", "정관", "편재", "정재", "식신", "상관", "편인", "정인", "겁재", "비견",
  "합충", "자오충", "삼합", "육합", "도화", "역마", "화개", "백호", "양인", "괴강",
  "공망", "천을귀인", "용신", "희신", "대운", "세운", "월운", "신강", "신약", "격국",
];
const FORBIDDEN = ["반드시", "무조건", "100%", "절대", "죽습니다", "바람난", "굿을", "귀신", "신내림"];

describe("ReadingResult 몰입 렌더링", () => {
  const html = renderToStaticMarkup(<ReadingResult session={makeSession(REPLY)} />);

  it("첫 점괘·마지막 점괘 히어로가 렌더된다", () => {
    expect(html).toContain("reading-oracle--opening");
    expect(html).toContain("reading-oracle--closing");
    expect(html).toContain("방향을 잃어서 지친 상태");
    expect(html).toContain("끊어내는 시기");
  });

  it("분야별 요약 카드가 4개 렌더된다", () => {
    for (const label of ["직업·재물", "애정·관계", "건강·컨디션", "멘탈·감정"]) {
      expect(html).toContain(label);
    }
  });

  it("본문 섹션(건강과 컨디션)이 펼쳐진 카드로 나온다", () => {
    expect(html).toContain("건강과 컨디션");
    expect(html).toContain("reading-section--open");
  });

  it("마크다운 기호가 화면 텍스트에서 제거된다", () => {
    // 굵게 기호, 본문 목록 기호, 헤딩 기호가 남지 않아야 함
    expect(html).not.toContain("**");
    expect(html).not.toContain("# 첫 점괘");
    // 본문의 "- 잠들기 전..." 목록 기호가 제거되어 문장만 남음
    expect(html).toContain("잠들기 전 생각이 길어지는 편");
    expect(html).not.toContain("- 잠들기 전");
  });

  it("표면 텍스트에 사주 전문용어가 없다", () => {
    for (const w of JARGON) expect(html, `사주 용어 노출: ${w}`).not.toContain(w);
  });

  it("금지 표현이 없다", () => {
    for (const w of FORBIDDEN) expect(html, `금지 표현: ${w}`).not.toContain(w);
  });
});

describe("ReadingResult 견고성", () => {
  it("빈 응답이어도 크래시하지 않는다", () => {
    const html = renderToStaticMarkup(<ReadingResult session={makeSession("")} />);
    expect(html).toContain("reading-result");
  });

  it("마크다운 없는 순수 문단도 그대로 렌더된다", () => {
    const html = renderToStaticMarkup(<ReadingResult session={makeSession("# 첫 점괘\n오늘은 무난한 하루예요.")} />);
    expect(html).toContain("오늘은 무난한 하루예요.");
  });

  it("계산값이 있으면 패턴 지도와 월별 실행 캘린더를 보여준다", () => {
    const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
    const session = {
      ...makeSession("# 첫 점괘\n오늘은 무난한 하루예요."),
      sajuChart: computeSajuChart(birth),
      luckCycles: computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"), { includeMonthlyFlow: true }),
    };
    const html = renderToStaticMarkup(<ReadingResult session={session} />);
    expect(html).toContain("근거 신뢰도");
    expect(html).toContain("내 반복 패턴 지도");
    expect(html).toContain("월별 실행 캘린더");
    expect(html).toContain("조정법");
  });
});
