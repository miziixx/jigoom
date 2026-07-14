import { describe, expect, it } from "vitest";
import {
  startStudy,
  answerStudy,
  gradeAnswer,
  formatProgress,
  isStudyExit,
  isDeepExplainRequest,
  deepExplainContext,
  emptyStudyState,
  getTextbookChart,
  TOTAL_CHAPTERS,
  type StudyState,
} from "./studyMode.js";

describe("학습모드 — 교재 사주", () => {
  it("교재 사주(임진 기묘 갑술 경오)가 학습에 필요한 특징을 실제로 갖는다", () => {
    const c = getTextbookChart();
    expect(c.dayMasterGan).toBe("갑");
    expect(c.interactions ?? []).toContain("연지-일지 진술충");
    expect((c.stemClashes ?? []).some((s) => s.includes("갑경충"))).toBe(true);
    expect((c.storageOpenings ?? []).length).toBeGreaterThanOrEqual(2); // 진·술 개고
    expect(c.gongmang).toContain("신유");
  });
});

describe("학습모드 — 채점", () => {
  it("정규화 매칭: 공백·조사 섞여도 정답 인정", () => {
    expect(gradeAnswer("화", ["화"])).toBe(true);
    expect(gradeAnswer("신유 공망이요", ["신유"])).toBe(true);
    expect(gradeAnswer("정재!", ["정재"])).toBe(true);
    expect(gradeAnswer("토", ["화"])).toBe(false);
    expect(gradeAnswer("", ["화"])).toBe(false);
  });

  it("한 글자 정답은 포함이 아니라 일치만 인정 (오답 문장에 우연히 낀 글자로 통과 금지)", () => {
    expect(gradeAnswer("화가 아니라 수", ["화"])).toBe(false);
  });
});

describe("학습모드 — 진행 흐름", () => {
  it("시작하면 1장 강의 + 첫 문제가 나온다", () => {
    const { state, message } = startStudy(null);
    expect(state.chapter).toBe(1);
    expect(state.quiz).not.toBeNull();
    expect(state.quiz!.length).toBeGreaterThanOrEqual(5);
    expect(message).toContain("음양오행");
    expect(message).toContain("[1장 · 1/");
  });

  it("전 문제 정답이면 통과하고 다음 장으로 넘어간다", () => {
    let { state } = startStudy(null);
    let lastMessage = "";
    while (state.quiz && state.qIndex < state.quiz.length) {
      const cur = state.quiz[state.qIndex];
      const reply = answerStudy(state, cur.answers[0]);
      state = reply.state;
      lastMessage = reply.message;
    }
    expect(state.chapter).toBe(2);
    expect(state.passed).toContain(1);
    expect(state.quiz).toBeNull();
    expect(lastMessage).toContain("통과");
  });

  it("전부 틀리면 통과 못 하고 같은 장에 머문다 + 오답노트에 쌓인다", () => {
    let { state } = startStudy(null);
    const quizLen = state.quiz!.length;
    let lastMessage = "";
    for (let i = 0; i < quizLen; i++) {
      const reply = answerStudy(state, "완전틀린답임");
      state = reply.state;
      lastMessage = reply.message;
    }
    expect(state.chapter).toBe(1);
    expect(state.passed).not.toContain(1);
    expect(state.wrongNotes.length).toBeGreaterThan(0);
    expect(lastMessage).toContain("80%");
  });

  it("오답노트 문제를 복습에서 맞히면 해소된다", () => {
    // 오답노트를 수동으로 심고 재시작 → 복습 문제 등장 → 정답 → 노트에서 제거
    const base = emptyStudyState();
    base.wrongNotes = [{ chapter: 1, prompt: "목이(가) 생(生)하는 오행은?", answers: ["화"], explain: "목생화." }];
    let { state } = startStudy(base);
    const reviewIdx = state.quiz!.findIndex((x) => x.isReview);
    expect(reviewIdx).toBeGreaterThanOrEqual(0);
    // 복습 문제가 나올 때까지 순서대로 답한다
    while (state.qIndex < state.quiz!.length) {
      const cur = state.quiz![state.qIndex];
      const reply = answerStudy(state, cur.answers[0]);
      state = reply.state;
      if (cur.isReview) break;
    }
    expect(state.wrongNotes.some((w) => w.prompt.includes("생(生)"))).toBe(false);
  });

  it("'패스'는 오답 처리 + 정답 공개", () => {
    const { state } = startStudy(null);
    const reply = answerStudy(state, "패스");
    expect(reply.message).toContain("정답은");
    expect(reply.state.stats.answered).toBe(1);
    expect(reply.state.stats.correct).toBe(0);
  });

  it("장 점프(/학습 17)로 해당 장 강의가 나온다", () => {
    const { state, message } = startStudy(emptyStudyState(), 17);
    expect(state.chapter).toBe(17);
    expect(message).toContain("공망");
  });

  it("21장 전부 통과하면 수료(자유 복습) 모드가 된다", () => {
    let state: StudyState = emptyStudyState();
    state.chapter = TOTAL_CHAPTERS; // 마지막 장
    state.passed = Array.from({ length: TOTAL_CHAPTERS - 1 }, (_, i) => i + 1);
    let reply = startStudy(state);
    state = reply.state;
    while (state.quiz && state.qIndex < state.quiz.length) {
      reply = answerStudy(state, state.quiz[state.qIndex].answers[0]);
      state = reply.state;
    }
    expect(reply.message).toContain("수료");
    expect(state.chapter).toBe(22);
    // 수료 후 /학습 → 무작위 복습 퀴즈
    const again = startStudy(state);
    expect(again.state.quiz!.length).toBeGreaterThan(0);
    expect(again.message).toContain("복습");
  });
});

describe("학습모드 — 문제 은행 무결성", () => {
  it("1~21장 전 장의 모든 문제가 유효하다(정답 존재, 자기 정답으로 채점 통과)", () => {
    for (let ch = 1; ch <= TOTAL_CHAPTERS; ch++) {
      // 각 장을 여러 번 뽑아 랜덤 생성 문제도 검증
      for (let rep = 0; rep < 3; rep++) {
        const { state } = startStudy(emptyStudyState(), ch);
        for (const question of state.quiz!) {
          expect(question.prompt.length).toBeGreaterThan(0);
          expect(question.answers.length).toBeGreaterThan(0);
          expect(question.explain.length).toBeGreaterThan(0);
          expect(gradeAnswer(question.answers[0], question.answers)).toBe(true);
        }
      }
    }
  });
});

describe("학습모드 — 딥다이브('더 설명해줘')", () => {
  it("트리거 문구를 인식한다", () => {
    expect(isDeepExplainRequest("더 설명해줘")).toBe(true);
    expect(isDeepExplainRequest("자세히 설명해줘")).toBe(true);
    expect(isDeepExplainRequest("왜 그런지 알려줘")).toBe(true);
    expect(isDeepExplainRequest("정재")).toBe(false);
    expect(isDeepExplainRequest("패스")).toBe(false);
  });

  it("시작 직후(강의 직후)에도 lastShown이 잡혀 컨텍스트를 만들 수 있다", () => {
    const { state } = startStudy(null);
    const ctx = deepExplainContext(state);
    expect(ctx).not.toBeNull();
    expect(ctx!.chapterTitle).toContain("음양오행");
    expect(ctx!.baseExplain.length).toBeGreaterThan(0);
  });

  it("문제를 채점하면 lastShown이 그 문제로 갱신된다", () => {
    let { state } = startStudy(null);
    const firstQuestion = state.quiz![0].prompt;
    const reply = answerStudy(state, "아무거나");
    state = reply.state;
    const ctx = deepExplainContext(state);
    expect(ctx!.concept).toBe(firstQuestion);
  });

  it("아직 시작 전(lastShown 없음)이면 컨텍스트가 null", () => {
    expect(deepExplainContext(emptyStudyState())).toBeNull();
  });
});

describe("학습모드 — 보조", () => {
  it("진도 요약", () => {
    expect(formatProgress(null)).toContain("/학습");
    const s = emptyStudyState();
    s.passed = [1, 2];
    s.chapter = 3;
    expect(formatProgress(s)).toContain("2/21");
  });

  it("종료 의사 판단", () => {
    expect(isStudyExit("/학습종료")).toBe(true);
    expect(isStudyExit("그만")).toBe(true);
    expect(isStudyExit("학습 끝")).toBe(true);
    expect(isStudyExit("화")).toBe(false);
    expect(isStudyExit("그만큼 좋아")).toBe(false);
  });
});
