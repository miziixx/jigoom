import { describe, expect, it } from "vitest";
import { JOHU_CLASSIC } from "./saju.js";

// 궁통보감 조후 120셀 자동 검수(sanity) 테스트.
// 목적: 표를 수정할 때 조후론의 기본 원리를 깨는 실수를 즉시 잡는다.
// (1순위 값은 서락오 정리 통용본과 대조해 확인함. 하위순위는 판본 차이 있어 원리 기반으로만 가드)

const STEMS = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"];
const MONTHS = ["인", "묘", "진", "사", "오", "미", "신", "유", "술", "해", "자", "축"];
const GAN_EL: Record<string, string> = {
  갑: "목", 을: "목", 병: "화", 정: "화", 무: "토", 기: "토", 경: "금", 신: "금", 임: "수", 계: "수",
};

describe("궁통보감 조후 120셀 검수", () => {
  it("10일간 × 12월지 = 120셀이 빠짐없이 채워져 있다", () => {
    let cells = 0;
    for (const s of STEMS) for (const m of MONTHS) {
      expect(Array.isArray(JOHU_CLASSIC[s]?.[m])).toBe(true);
      expect(JOHU_CLASSIC[s][m].length).toBeGreaterThan(0);
      cells++;
    }
    expect(cells).toBe(120);
  });

  it("모든 셀은 유효한 천간만, 중복 없이 담는다", () => {
    for (const s of STEMS) for (const m of MONTHS) {
      const cell = JOHU_CLASSIC[s][m];
      for (const g of cell) expect(GAN_EL[g], `${s}${m}의 ${g}`).toBeTruthy();
      expect(new Set(cell).size, `${s}${m} 중복`).toBe(cell.length);
    }
  });

  it("조후 원리(일간 자기온도 반영): 목·금·토 일간은 한여름(사·오)엔 水, 한겨울(해·자)엔 火를 조후로 갖는다", () => {
    // 火 일간(병·정)은 스스로 덥고, 水 일간(임·계)은 스스로 차가워 자기조절되므로 이 규칙에서 제외한다.
    // 늦여름 미(土旺)·늦겨울 축(전환기)도 열/한이 누그러지므로 제외하고, 극점인 사·오·해·자만 본다.
    const selfRegulating = (s: string) => ["화", "수"].includes(GAN_EL[s]);
    for (const s of STEMS) {
      if (selfRegulating(s)) continue;
      for (const m of ["사", "오"]) {
        const els = JOHU_CLASSIC[s][m].map((g) => GAN_EL[g]);
        expect(els, `${s}${m}(한여름)엔 식히는 水 필요: [${JOHU_CLASSIC[s][m]}]`).toContain("수");
      }
      for (const m of ["해", "자"]) {
        const els = JOHU_CLASSIC[s][m].map((g) => GAN_EL[g]);
        expect(els, `${s}${m}(한겨울)엔 데우는 火 필요: [${JOHU_CLASSIC[s][m]}]`).toContain("화");
      }
    }
  });

  it("원전 대조 스팟체크: 갑목 행과 임·계 핵심 셀이 서락오 통용본과 일치한다", () => {
    expect(JOHU_CLASSIC.갑.인).toEqual(["병", "계"]);
    expect(JOHU_CLASSIC.갑.사).toEqual(["계", "정", "경"]);
    expect(JOHU_CLASSIC.갑.신).toEqual(["경", "정", "임"]);
    expect(JOHU_CLASSIC.갑.자).toEqual(["정", "경", "병"]);
    expect(JOHU_CLASSIC.임.자).toEqual(["무", "병"]);
    expect(JOHU_CLASSIC.계.신).toEqual(["정"]);
  });
});
