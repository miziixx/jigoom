import { describe, expect, it } from "vitest";
import {
  startStudy,
  answerStudy,
  gradeAnswer,
  formatProgress,
  isStudyExit,
  isDeepExplainRequest,
  deepExplainContext,
  setStudyTone,
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

  it("유사어 사전: 쉬운 말·한자 표기를 서로 인정", () => {
    expect(gradeAnswer("불", ["화"])).toBe(true); // 화 = 불
    expect(gradeAnswer("나무", ["목"])).toBe(true); // 목 = 나무
    expect(gradeAnswer("흙", ["토"])).toBe(true);
    expect(gradeAnswer("물이요", ["수"])).toBe(true); // 조사 허용
    expect(gradeAnswer("네", ["아니오"])).toBe(false); // 반대 답은 여전히 오답
  });

  it("오타 관용: 편집거리 1 이내면 인정하되, 인접한 다른 정답은 차단", () => {
    expect(gradeAnswer("정제", ["정재"])).toBe(true); // 흔한 오타
    expect(gradeAnswer("정제요", ["정재"])).toBe(true); // 조사 섞인 오타
    expect(gradeAnswer("천을귀임", ["천을귀인"])).toBe(true); // 3글자 이상 오타
    expect(gradeAnswer("편관", ["정관"])).toBe(false); // 인접한 '다른 정답'은 오타로 통과 금지
    expect(gradeAnswer("정인", ["정재"])).toBe(false); // 십신 인접어도 통과 금지
  });
});

describe("학습모드 — 톤 설정", () => {
  it("톤을 저장하고, 새 장 강의 응답에 lesson/tail이 분리돼 나온다", () => {
    const { state: toned } = setStudyTone(null, "초등학생도 알게 쉽게");
    expect(toned.tone).toBe("초등학생도 알게 쉽게");
    const reply = startStudy(toned);
    expect(reply.state.tone).toBe("초등학생도 알게 쉽게"); // 톤 유지
    expect(reply.lesson).toBeTruthy();
    expect(reply.tail).toContain("[1장 · 1/");
  });

  it("빈 문자열이면 톤 해제(null)", () => {
    const { state: on } = setStudyTone(null, "존댓말로");
    const { state: off } = setStudyTone(on, "  ");
    expect(off.tone).toBeNull();
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
  it("깊이 요청 문구를 인식한다", () => {
    expect(isDeepExplainRequest("더 설명해줘")).toBe(true);
    expect(isDeepExplainRequest("자세히 설명해줘")).toBe(true);
    expect(isDeepExplainRequest("왜 그런지 알려줘")).toBe(true);
    expect(isDeepExplainRequest("좀 더 자세히")).toBe(true);
  });

  it("톤·난이도 지정 요청도 인식한다", () => {
    expect(isDeepExplainRequest("초등학생도 이해하게 쉽게 설명해줘")).toBe(true);
    expect(isDeepExplainRequest("쉽게 알려줘")).toBe(true);
    expect(isDeepExplainRequest("비유로 설명해줘")).toBe(true);
    expect(isDeepExplainRequest("예시 들어서 알려줘")).toBe(true);
    expect(isDeepExplainRequest("존댓말로 다시 설명해줘")).toBe(true);
    expect(isDeepExplainRequest("재미있게 풀어줘")).toBe(true);
  });

  it("짧은 퀴즈 답은 트리거로 오인하지 않는다", () => {
    expect(isDeepExplainRequest("정재")).toBe(false);
    expect(isDeepExplainRequest("패스")).toBe(false);
    expect(isDeepExplainRequest("화")).toBe(false);
    expect(isDeepExplainRequest("신유")).toBe(false);
    expect(isDeepExplainRequest("음토")).toBe(false);
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
