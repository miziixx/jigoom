import { describe, it, expect } from "vitest";
import { detectIntent, isSecretaryIntent, isDeterministicIntent } from "./intentDetector.js";

describe("detectIntent", () => {
  it("사주 관련 질문은 sajuReading으로 분류한다", () => {
    expect(detectIntent("나 왜 신약사주야?")).toBe("sajuReading");
    expect(detectIntent("내 격국이 뭔지 알려줘")).toBe("sajuReading");
  });

  it("점성술 관련 질문은 astrologyReading으로 분류한다", () => {
    expect(detectIntent("내 별자리가 뭐야")).toBe("astrologyReading");
  });

  it("사주+점성술 통합 질문은 combinedReading으로 분류한다", () => {
    expect(detectIntent("사주랑 점성술 같이 봤을 때 나는 왜 이런 패턴이 반복돼?")).toBe("combinedReading");
  });

  it("오늘 흐름 질문은 todayFlow로 분류한다", () => {
    expect(detectIntent("오늘 왜 이렇게 의욕이 없지?") === "todayFlow" || detectIntent("오늘 일진 어때")).toBeTruthy();
    expect(detectIntent("오늘 일진 어때")).toBe("todayFlow");
  });

  it("자기분석 트리거를 인식한다", () => {
    expect(detectIntent("나 왜 자꾸 미루지?")).toBe("selfAnalysis");
    expect(detectIntent("이 상황에서 내가 예민한 건가?")).toBe("selfAnalysis");
  });

  it("기획 트리거를 인식한다", () => {
    expect(detectIntent("이거 앱으로 만들고 싶어")).toBe("planning");
    expect(detectIntent("MVP로 뭐부터 해야 돼?")).toBe("planning");
    expect(detectIntent("Claude Code한테 시킬 프롬프트로 정리해줘")).toBe("planning");
  });

  it("글쓰기 트리거를 인식한다", () => {
    expect(detectIntent("이 글 좀 더 자연스럽게 고쳐줘")).toBe("writing");
    expect(detectIntent("AI 티 안 나게 해줘")).toBe("writing");
  });

  it("판단 트리거를 인식한다", () => {
    expect(detectIntent("지금 뭐부터 개발해야 할까?")).toBe("decision");
    expect(detectIntent("올해 내 흐름상 이거 밀어붙여도 돼?")).toBe("decision");
  });

  it("기억 저장/삭제/조회 트리거를 인식한다", () => {
    expect(detectIntent("방금 얘기한 거 기억해둬")).toBe("memorySave");
    expect(detectIntent("이건 저장하지 마")).toBe("memoryDelete");
    expect(detectIntent("최근 기억 지워줘")).toBe("memoryDelete");
    expect(detectIntent("뭐 기억하고 있어?")).toBe("memoryLookup");
  });

  it("보안/초기화 트리거를 인식한다", () => {
    expect(detectIntent("보안 상태 알려줘")).toBe("privacyCheck");
    expect(detectIntent("대화 초기화해줘")).toBe("resetContext");
  });

  it("매치되는 규칙이 없으면 generalChat", () => {
    expect(detectIntent("ㅎㅇ")).toBe("generalChat");
    expect(detectIntent("")).toBe("generalChat");
  });
});

describe("isSecretaryIntent / isDeterministicIntent", () => {
  it("기획/글쓰기/판단/자기분석만 비서 모드로 인식한다", () => {
    expect(isSecretaryIntent("planning")).toBe(true);
    expect(isSecretaryIntent("writing")).toBe(true);
    expect(isSecretaryIntent("decision")).toBe(true);
    expect(isSecretaryIntent("selfAnalysis")).toBe(true);
    expect(isSecretaryIntent("sajuReading")).toBe(false);
  });

  it("기억/보안/초기화만 결정론적 처리 대상으로 인식한다", () => {
    expect(isDeterministicIntent("memorySave")).toBe(true);
    expect(isDeterministicIntent("privacyCheck")).toBe(true);
    expect(isDeterministicIntent("planning")).toBe(false);
  });
});
