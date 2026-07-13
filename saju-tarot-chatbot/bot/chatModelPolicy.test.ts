import { describe, expect, it } from "vitest";
import { shouldUseChatModel } from "./chatModelPolicy.js";

describe("shouldUseChatModel — 잡담만 값싼 모델", () => {
  it("순수 잡담(generalChat)은 값싼 모델", () => {
    for (const q of ["안녕", "고마워", "ㅋㅋㅋ", "오늘 뭐하지", "너 누구야?", "밥 먹었어?"]) {
      expect(shouldUseChatModel("generalChat", q)).toBe(true);
    }
  });

  it("사주 관련 intent는 잡담이 아니므로 기본 모델", () => {
    for (const intent of ["sajuReading", "astrologyReading", "combinedReading", "todayFlow", "tarotReading"]) {
      expect(shouldUseChatModel(intent, "안녕")).toBe(false);
    }
  });

  it("generalChat이어도 사주/명리 용어가 섞이면 기본 모델(정확도 보호)", () => {
    const sajuish = [
      "내 사주 어때",
      "년지 지장간에 정 있으면 투출 아니야?",
      "나 신강이야 신약이야",
      "용신이 뭐야",
      "이번 대운 어떻게 흘러가",
      "우리 궁합 봐줘",
      "타로 한 장 뽑아줘",
      "오행 분포 설명해줘",
    ];
    for (const q of sajuish) {
      expect(shouldUseChatModel("generalChat", q)).toBe(false);
    }
  });

  it("일상어 오탐 방지: 합/충/형/파/해가 든 일상어는 잡담으로 남는다", () => {
    // 단일 글자를 사전에서 뺐으므로 아래는 전부 잡담(값싼 모델)이어야 한다.
    for (const q of ["합정역 맛집 알아?", "폰 충전 좀", "그거 이해했어", "파일 보냈어?", "오늘 뭐 해?"]) {
      expect(shouldUseChatModel("generalChat", q)).toBe(true);
    }
  });
});
