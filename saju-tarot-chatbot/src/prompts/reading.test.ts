import { describe, expect, it } from "vitest";
import { READING_SYSTEM_PROMPT, buildCompareUserMessage, buildReadingUserMessage } from "./systemPrompt.js";
import { computeSajuChart, computeLuckCycles } from "../lib/saju.js";
import { drawSpread } from "../lib/tarot.js";
import type { BirthInfo } from "../types/index.js";

describe("리딩 시스템 프롬프트 규칙", () => {
  it("사주 전문용어 금지 규칙을 담는다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("사주 전문용어를 사용자에게 보이는 문장에 절대 쓰지 않는다");
  });
  it("마크다운 금지 규칙을 담는다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("마크다운 기호를 쓰지 않는다");
  });
  it("나이는 숫자로 표기하라는 규칙을 담는다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("40세");
    expect(READING_SYSTEM_PROMPT).toContain("한글 나이 표현을 쓰지 말고");
  });
  it("종합 사주풀이 섹션(성격·직업·애정·건강·대운·세운)을 담는다", () => {
    for (const s of [
      "# 첫 점괘",
      "# 타고난 성격과 기질",
      "# 직업과 돈",
      "# 애정과 관계",
      "# 건강과 컨디션",
      "# 인생의 큰 흐름",
      "# 올해의 흐름",
      "# 마지막 점괘",
    ]) {
      expect(READING_SYSTEM_PROMPT).toContain(s);
    }
  });
  it("섹션 간 내용 중복 방지 규칙을 담는다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("중복 방지 — 섹션 담당 구분");
    expect(READING_SYSTEM_PROMPT).toContain("재물 흐름으로 넘겨라");
  });
  it("안전 규칙(단정·무속 금지)을 유지한다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("반드시/무조건/100%/절대");
    expect(READING_SYSTEM_PROMPT).toContain("무속");
  });

  it("상담형 판단과 흔한 말 감지 규칙을 담는다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("상담형 판단 원칙");
    expect(READING_SYSTEM_PROMPT).toContain("선택지 비교");
    expect(READING_SYSTEM_PROMPT).toContain("듣기 싫어도 봐야 할 부분");
    expect(READING_SYSTEM_PROMPT).toContain("흔한 말 감지");
  });

  it("모든 리딩에서 질문 의도를 먼저 파악하도록 요구한다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("질문 의도 파악");
    expect(READING_SYSTEM_PROMPT).toContain("질문 뒤의 실제 의도");
    expect(READING_SYSTEM_PROMPT).toContain("사용자가 알고 싶은 핵심");
    expect(READING_SYSTEM_PROMPT).toContain("실제 선택 압박");
  });

  it("한 줄 결론은 질문 요약이 아니라 판단형 문장으로 쓰도록 요구한다", () => {
    expect(READING_SYSTEM_PROMPT).toContain("분석형 문장은 결론이 아니다");
    expect(READING_SYSTEM_PROMPT).toContain("어떤 선택이 더 안전한지");
    expect(READING_SYSTEM_PROMPT).toContain("그것을 [한 줄 결론] 자리에 쓰지 않는다");
  });
});

describe("근거 직렬화(LLM 내부용)는 계산값을 담는다", () => {
  const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
  const sajuChart = computeSajuChart(birth);
  const luckCycles = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));
  const msg = buildReadingUserMessage({ type: "saju", question: "요즘 지쳐요", gender: birth.gender, sajuChart, luckCycles });

  it("기본 리딩은 JudgmentPack 압축 판단 근거(Evidence Gate)를 전달한다", () => {
    // 기본(depth 미지정)은 원자료를 그대로 펼치지 않고, 판단 엔진이 미리 계산·검증한 JudgmentPack만
    // 근거로 받는다(마스터 프롬프트: "가벼운 리딩에서는 긴 계산 원문을 펼치지 않는다"). 고급은
    // 아래 "깊이를 고르면..." 테스트에서 원자료(상세 계산 근거)를 그대로 받는 걸 확인한다.
    expect(msg).toContain("[JudgmentPack — 계산됨]");
    expect(msg).toContain("JudgmentPack 활용 안내");
    expect(msg).toContain(sajuChart.day.ganZhi);
    expect(msg).not.toContain("상세 계산 근거 — 사주 원국");
    expect(msg).not.toContain("[상세 계산 근거 — 대운/세운/월운/일진]");
  });

  it("개인정보 보호: 생년월일 원본은 AI 메시지에 담지 않는다", () => {
    // 계산 결과와 성별만 전달하고, 생년월일 원본 문자열은 넣지 않는다
    expect(msg).not.toContain("1990년");
    expect(msg).not.toContain("생년월일시");
    expect(msg).toContain("성별");
  });

  it("기본 리딩에서는 분야별 사건 신호가 별도 블록 대신 JudgmentPack 판단 안에 녹아 들어간다", () => {
    expect(msg).not.toContain("분야별 사건 신호 — 계산됨");
    expect(msg).not.toContain("사건 신호 활용 안내");
    // 분야 라벨은 JudgmentPack의 judgment 근거 줄 안에 그대로 남아 있다
    expect(msg).toContain("직업·일");
    expect(msg).toContain("건강·컨디션");
  });

  it("과거 검증 결과가 있으면 근거 블록과 활용 안내를 전달한다", () => {
    const withPast = buildReadingUserMessage({
      type: "saju",
      question: "요즘 지쳐요",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      pastValidation: {
        matches: [
          {
            year: 2021,
            domain: "career",
            domainLabel: "직업·일",
            note: "이직",
            level: "strong",
            summary: "2021년 직업·일 사건은 그 시기 흐름과 잘 맞습니다.",
            evidence: ["세운 신축"],
          },
        ],
        headline: "과거 사건들이 계산된 흐름과 대체로 잘 맞습니다.",
        reliableDomains: ["career"],
      },
    });
    expect(withPast).toContain("과거 사건 검증 — 계산됨");
    expect(withPast).toContain("과거 검증 활용 안내");
    expect(withPast).toContain("2021년 직업·일");
  });

  it("깊이 미선택이면 평생사주 기본 리포트 프로필을 붙인다", () => {
    expect(msg).toContain("기본 리딩 — 종합");
    expect(msg).toContain("평생사주 기본 리포트");
    expect(msg).toContain("# 재물 흐름");
    expect(msg).toContain("# 애정과 관계");
    expect(msg).toContain("# 건강과 컨디션");
    expect(msg).toContain("# 인생의 큰 흐름");
    expect(msg).toContain("4200~6000자");
    expect(msg).toContain("성향 / 직업·돈 / 재물 / 연애·관계 / 건강·컨디션 / 올해 흐름 6개 항목");
    expect(msg).toContain("각 항목을 1~2줄");
    expect(msg).toContain("질문 답변은 전체의 약 30%");
    expect(msg).toContain("기본 사주 핵심은 약 70%");
    expect(msg).toContain("나머지 기본 6분야를 누락하지 마라");
    expect(msg).toContain("일부러 숨기거나 끊어낸 느낌");
    expect(msg).toContain("결제를 유도하려고 비워둔 느낌을 절대 내지 마라");
    expect(msg).not.toContain("무료 미리보기");
    expect(msg).not.toContain("맛보기");
  });

  it("깊이를 고르면 기본 종합 프로필 대신 해당 깊이를 쓴다", () => {
    const deep = buildReadingUserMessage({
      type: "saju",
      question: "요즘 지쳐요",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      context: { depth: "advanced" },
    });
    expect(deep).not.toContain("[기본 리딩 — 종합]");
    expect(deep).toContain("상세 계산 근거 — 사주 원국");
    expect(deep).toContain("상세 계산 근거 — 대운/세운/월운/일진");
    expect(deep).toContain("정밀 리포트");
    expect(deep).toContain("# 반복 패턴 정밀 진단");
    expect(deep).toContain("# 선택과 시기 판단");
    expect(deep).toContain("# 3개월 실행 전략");
    expect(deep).toContain("6200~8000자");
    // 고급은 원자료(지장간·12운성)와 분야별 사건 신호 블록을 그대로 받는다(기본은 JudgmentPack으로 대체).
    expect(deep).toContain("지장간");
    expect(deep).toContain("12운성");
    expect(deep).toContain("분야별 사건 신호 — 계산됨");
    expect(deep).toContain("사건 신호 활용 안내");
    expect(deep).not.toContain("[JudgmentPack — 계산됨]");
  });

  it("병렬 생성을 위해 지정 섹션만 쓰라는 지시를 붙일 수 있다", () => {
    const front = buildReadingUserMessage({
      type: "saju",
      question: "전체",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      sectionGroup: "front",
    });
    const back = buildReadingUserMessage({
      type: "saju",
      question: "전체",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      sectionGroup: "back",
    });

    expect(front).toContain("병렬 생성 — 앞부분만 작성");
    expect(front).toContain("# 재물 흐름");
    expect(front).toContain("건강과 컨디션");
    expect(front).toContain("절대 쓰지 마라");
    expect(back).toContain("병렬 생성 — 뒷부분만 작성");
    expect(back).toContain("# 건강과 컨디션");
    expect(back).toContain("첫 점괘");
    expect(back).toContain("절대 쓰지 마라");
  });

  it("상담형 입력은 선택지·최근 상황·두려운 결과를 메시지에 담는다", () => {
    const msg = buildReadingUserMessage({
      type: "saju",
      question: "회사를 계속 다닐지 퇴사할지 고민돼요",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      context: {
        concernArea: "일·커리어",
        optionsText: "A: 지금 회사 유지 / B: 퇴사 후 프리랜서 준비",
        recentContext: "최근 2개월 동안 업무량이 늘고 사람 문제로 지쳤어요.",
        fearPoint: "퇴사했다가 돈이 끊길까 봐 걱정돼요.",
        tone: "action",
      },
    });

    expect(msg).toContain("현재 고민 분야: 일·커리어");
    expect(msg).toContain("고민 중인 선택지: A: 지금 회사 유지 / B: 퇴사 후 프리랜서 준비");
    expect(msg).toContain("최근 1~3개월 실제 상황: 최근 2개월 동안 업무량이 늘고 사람 문제로 지쳤어요.");
    expect(msg).toContain("가장 두려운 결과: 퇴사했다가 돈이 끊길까 봐 걱정돼요.");
    expect(msg).toContain("[선택지 비교]");
    expect(msg).toContain("[듣기 싫어도 봐야 할 부분]");
    expect(msg).toContain("오늘 할 일, 이번 주 확인할 신호, 이번 달 조정할 조건");
  });
});

describe("타로 리딩 프롬프트", () => {
  const tarotCards = drawSpread("ppf");

  it("순수 타로는 사주 종합 생애 리딩을 강요하지 않고 질문·카드에 집중한다", () => {
    const msg = buildReadingUserMessage({ type: "tarot", question: "이 관계 계속해도 될까요?", tarotCards });
    expect(msg).toContain("타로 리딩 — 질문 집중");
    expect(msg).toContain("# 카드가 그리는 흐름");
    expect(msg).not.toContain("기본 리딩 — 종합");
    // 사주 기반 생애 섹션을 억지로 채우지 말라는 지시를 담는다
    expect(msg).toContain("억지로 채우지 마라");
  });

  it("원소 조합(엘리멘탈 디그니티) 근거를 계산해 전달한다", () => {
    const msg = buildReadingUserMessage({ type: "tarot", question: "이직해도 될까요?", tarotCards });
    expect(msg).toContain("원소 조합(엘리멘탈 디그니티)");
    expect(msg).toContain("원소 분포");
  });

  it("깊이를 골라도 타로는 사주 섹션을 강요하지 않는다", () => {
    const msg = buildReadingUserMessage({
      type: "tarot",
      question: "이직해도 될까요?",
      tarotCards,
      context: { depth: "advanced" },
    });
    expect(msg).toContain("타로 리딩 — 질문 집중");
    expect(msg).not.toContain("기본 리딩 — 종합");
  });
});

describe("통합 리딩 프롬프트", () => {
  const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
  const sajuChart = computeSajuChart(birth);
  const luckCycles = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));
  const tarotCards = drawSpread("ppf");

  it("질문 분야와 무관하게 사주+타로 통합 고정 섹션을 요구한다", () => {
    const msg = buildReadingUserMessage({
      type: "combo",
      question: "이직해도 될까요?",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      tarotCards,
      context: { concernArea: "일·커리어" },
    });

    expect(msg).toContain("통합 리딩 고정 구조");
    expect(msg).toContain("질문이 연애·돈·일·관계·건강·선택·전반 중 무엇이든");
    expect(msg).toContain("# 사주로 보는 장기 흐름");
    expect(msg).toContain("# 타로로 보는 현재 흐름");
    expect(msg).toContain("# 통합 판단");
    expect(msg).toContain("둘 중 하나만 보고 결론을 내리지 마라");
  });

  it("질문이 없어도 통합 핵심 섹션을 생략하지 않도록 요구한다", () => {
    const msg = buildReadingUserMessage({
      type: "combo",
      question: "",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      tarotCards,
    });

    expect(msg).toContain("사용자가 질문을 쓰지 않았더라도 '# 질문 중심 핵심'을 생략하지 말고");
    expect(msg).toContain("# 첫 점괘\n# 질문 중심 핵심\n# 사주로 보는 장기 흐름");
  });

  it("병렬 앞부분 생성에서도 통합 섹션 순서를 고정한다", () => {
    const msg = buildReadingUserMessage({
      type: "combo",
      question: "연애운이 궁금해요",
      gender: birth.gender,
      sajuChart,
      luckCycles,
      tarotCards,
      sectionGroup: "front",
    });

    expect(msg).toContain("병렬 생성 — 앞부분만 작성");
    expect(msg).toContain("통합 리딩에서는 질문이 없어도 '# 질문 중심 핵심'을 생략하지 말고");
    expect(msg).toContain("# 질문 중심 핵심\n# 사주로 보는 장기 흐름\n# 타로로 보는 현재 흐름\n# 통합 판단");
  });
});

describe("오늘/흐름 리딩은 종합 생애 섹션을 강요하지 않는다", () => {
  const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
  const sajuChart = computeSajuChart(birth);
  const luckCycles = computeLuckCycles(birth, new Date("2026-07-03T03:00:00Z"));

  it("오늘 리딩은 집중 섹션만 쓰고 생애 섹션은 배제한다", () => {
    const msg = buildReadingUserMessage({ type: "today", question: "오늘 어때요?", gender: birth.gender, sajuChart, luckCycles });
    expect(msg).toContain("오늘의 흐름 안내");
    expect(msg).toContain("종합 생애 섹션은 절대 쓰지 마라");
    expect(msg).not.toContain("기본 리딩 — 종합");
  });

  it("흐름 리딩은 시기 섹션에 집중하고 생애 섹션은 배제한다", () => {
    const msg = buildReadingUserMessage({ type: "flow", question: "올해 어때요?", gender: birth.gender, sajuChart, luckCycles });
    expect(msg).toContain("월간/연간 흐름 안내");
    expect(msg).toContain("종합 생애 섹션은 이 리딩에서 쓰지 마라");
    expect(msg).toContain("1월부터 12월까지");
    expect(msg).not.toContain("기본 리딩 — 종합");
  });
});

describe("비교 리딩 프롬프트", () => {
  it("A/B 선택 기준을 정리하도록 요구한다", () => {
    const msg = buildCompareUserMessage(
      { type: "saju", createdAt: "2026-07-03T00:00:00.000Z", question: "이직", reply: "A" },
      { type: "flow", createdAt: "2026-07-04T00:00:00.000Z", question: "유지", reply: "B" },
    );
    expect(msg).toContain("A/B 선택 비교 리포트");
    expect(msg).toContain("# A를 선택할 때 유리한 조건");
    expect(msg).toContain("# 선택 기준표");
    expect(msg).toContain("안정성 / 성장 가능성 / 관계 부담 / 돈의 흐름 / 실행 타이밍");
  });
});
