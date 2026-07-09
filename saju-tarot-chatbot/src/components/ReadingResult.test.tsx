import { renderToStaticMarkup } from "react-dom/server";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import ReadingResult from "./ReadingResult.js";
import { computeLuckCycles, computeSajuChart } from "../lib/saju.js";
import { TAROT_DECK } from "../data/tarotDeck.js";
import type { BirthInfo, DrawnTarotCard, ReadingSession } from "../types/index.js";

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
  const html = renderToStaticMarkup(<MemoryRouter><ReadingResult session={makeSession(REPLY)} /></MemoryRouter>);

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

  it("짧은 라벨이 없는 소제목은 같은 말을 배지와 제목에 중복 표시하지 않는다", () => {
    const reply = [
      "# 첫 점괘",
      "지금은 흐름을 정리할 때입니다.",
      "",
      "# 질문 중심 핵심",
      "[듣기 싫어도 봐야 할 부분]",
      "지금은 마음만 앞서면 같은 문제가 반복될 수 있어요.",
      "",
      "[한 줄 결론]",
      "결정 전에 조건을 먼저 확인하세요.",
    ].join("\n");
    const html = renderToStaticMarkup(<MemoryRouter><ReadingResult session={makeSession(reply)} /></MemoryRouter>);

    expect(html).toContain("듣기 싫어도 봐야 할 부분");
    expect(html).not.toContain('<span class="reading-part__label">듣기 싫어도 봐야 할 부분</span>');
    expect(html).toContain('<span class="reading-part__label">결론</span>');
  });

  it("총평 뒤에 목차를 제공하고 세부 섹션은 접힘 영역으로 렌더된다", () => {
    expect(html).toContain("reading-toc");
    expect(html).toContain("필요한 부분을 눌러 바로 이동하세요");
    expect(html).toContain('id="reading-건강과-컨디션"');
    expect(html).toContain('class="reading-toc__link"');
    expect(html).toContain("<details");
  });

  it("분야별 요약이 아이콘·픽토그래프 카드와 집계 스트립으로 렌더된다", () => {
    expect(html).toContain("reading-category-tally");
    expect(html).toContain("rating-cell--caution");
    expect(html).toContain("category-icon--love");
    // 평가 단어는 항상 텍스트로 함께 노출 (색만으로 구분 금지)
    expect(html).toContain("<b>주의</b>");
  });

  it("섹션 헤더에 tone 아이콘이 붙는다", () => {
    expect(html).toContain("reading-section__icon");
    expect(html).toContain("category-icon--health");
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
    const html = renderToStaticMarkup(<MemoryRouter><ReadingResult session={makeSession("")} /></MemoryRouter>);
    expect(html).toContain("reading-result");
  });

  it("마크다운 없는 순수 문단도 그대로 렌더된다", () => {
    const html = renderToStaticMarkup(<MemoryRouter><ReadingResult session={makeSession("# 첫 점괘\n오늘은 무난한 하루예요.")} /></MemoryRouter>);
    expect(html).toContain("오늘은 무난한 하루예요.");
  });

  it("계산값이 있으면 패턴 지도와 월별 실행 캘린더를 보여준다", () => {
    const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
    const session = {
      ...makeSession("# 첫 점괘\n오늘은 무난한 하루예요."),
      sajuChart: computeSajuChart(birth),
      luckCycles: computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"), { includeMonthlyFlow: true }),
    };
    const html = renderToStaticMarkup(<MemoryRouter><ReadingResult session={session} /></MemoryRouter>);
    expect(html).toContain("근거 신뢰도");
    expect(html).toContain("내 반복 패턴 지도");
    expect(html).toContain("월별 실행 캘린더");
    expect(html).toContain("조정법");
    expect(html).toContain("reading-evidence-zone");
  });

  it("사주 원국 4기둥은 항상 보이고, 계산 근거 상세는 목차 다음 접힌 영역 안에, 본문보다 앞에 온다", () => {
    const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
    const session = {
      ...makeSession(REPLY),
      sajuChart: computeSajuChart(birth),
      luckCycles: computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"), { includeMonthlyFlow: true }),
    };
    const html = renderToStaticMarkup(<MemoryRouter><ReadingResult session={session} /></MemoryRouter>);
    const pillarIdx = html.indexOf("내 사주 원국");
    const tocIdx = html.indexOf("reading-toc__link");
    const evidenceIdx = html.indexOf("reading-evidence-zone");
    // 본문 섹션 카드만 특정한다("id=\"reading-"는 B-3에서 첫/마지막 점괘·질문 핵심에도
    // 앵커(sectionAnchor)를 붙여 더 이상 본문 섹션 전용 접두어가 아니게 됐다).
    const bodyIdx = html.indexOf("reading-section reading-section--open");

    expect(pillarIdx).toBeGreaterThan(-1);
    expect(tocIdx).toBeGreaterThan(-1);
    expect(evidenceIdx).toBeGreaterThan(-1);
    expect(bodyIdx).toBeGreaterThan(-1);
    expect(pillarIdx).toBeLessThan(tocIdx);
    expect(tocIdx).toBeLessThan(evidenceIdx);
    expect(evidenceIdx).toBeLessThan(bodyIdx);
    // 4기둥은 한 번만(스냅샷) 보여야 한다 — 접힌 영역 안의 SajuFactsPanel은 showPillars=false로 중복 렌더하지 않는다
    expect(html.indexOf("내 사주 원국")).toBe(html.lastIndexOf("내 사주 원국"));
  });

  it("타로 카드가 있으면 헤드라인은 접힌 영역 밖에, 카드별 근거는 안에 둔다", () => {
    const cards: DrawnTarotCard[] = [
      { card: TAROT_DECK.find((c) => c.name.startsWith("The Fool"))!, reversed: false, position: 1, positionLabel: "핵심 메시지" },
    ];
    const session = { ...makeSession(REPLY), tarotCards: cards };
    const html = renderToStaticMarkup(<MemoryRouter><ReadingResult session={session} /></MemoryRouter>);
    const heroIdx = html.indexOf("tarot-hero");
    const evidenceIdx = html.indexOf("reading-evidence-zone");
    const factsIdx = html.indexOf("tarot-facts");

    expect(heroIdx).toBeGreaterThan(-1);
    expect(evidenceIdx).toBeGreaterThan(-1);
    expect(factsIdx).toBeGreaterThan(-1);
    expect(heroIdx).toBeLessThan(evidenceIdx);
    expect(evidenceIdx).toBeLessThan(factsIdx);
  });

  it("월별 근거 번역은 긴 문단 대신 월별 카드로 정리한다 (고정 포맷)", () => {
    const reply = [
      "# 첫 점괘",
      "올해는 흐름을 정리하는 힘이 중요합니다.",
      "",
      "# 올해의 흐름",
      "[왜 그렇게 보는지]",
      "올해 들어오는 기운이 관계와 일의 흐름을 함께 건드립니다.",
      "월별 흐름은 다음과 같습니다.",
      "1월 | 키워드: 정리와 다짐 | 기회: 새 계획을 세우기 좋은 시기 | 주의: 성급한 결정은 피하기 | 조언: 실행 가능한 계획을 세우세요",
      "2월 | 키워드: 평온 | 기회: 체력 회복 | 주의: 나태해지기 쉬움 | 조언: 체력과 마음을 채워두세요",
      "3월 | 키워드: 미묘한 긴장과 화합 | 기회: 관계 회복 | 주의: 오해가 쌓이기 쉬움 | 조언: 대화의 문은 열어두세요",
    ].join("\n");
    const html = renderToStaticMarkup(<MemoryRouter><ReadingResult session={makeSession(reply)} /></MemoryRouter>);

    expect(html).toContain("month-evidence-grid");
    expect(html).toContain("month-evidence-card");
    expect(html).toContain("정리와 다짐");
    expect(html).toContain("새 계획을 세우기 좋은 시기");
    expect(html).toContain("성급한 결정은 피하기");
    expect(html).toContain("대화의 문은 열어두세요");
  });

  it("고정 포맷 이전에 저장된 옛 산문 형식도 월별 카드로 폴백 파싱한다", () => {
    const reply = [
      "# 첫 점괘",
      "올해는 흐름을 정리하는 힘이 중요합니다.",
      "",
      "# 올해의 흐름",
      "[왜 그렇게 보는지]",
      "올해 들어오는 기운이 관계와 일의 흐름을 함께 건드립니다.",
      "월별 흐름은 다음과 같습니다.",
      "1월 — 키워드: 정리와 다짐. 조언: 실행 가능한 계획을 세우세요.",
      "2월 — 키워드: 평온. 조언: 체력과 마음을 채워두세요.",
      "3월 — 키워드: 미묘한 긴장과 화합. 조언: 대화의 문은 열어두세요.",
    ].join("\n");
    const html = renderToStaticMarkup(<MemoryRouter><ReadingResult session={makeSession(reply)} /></MemoryRouter>);

    expect(html).toContain("month-evidence-grid");
    expect(html).toContain("month-evidence-card");
    expect(html).toContain("정리와 다짐");
    expect(html).toContain("대화의 문은 열어두세요.");
  });
});
