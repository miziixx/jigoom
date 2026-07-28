import { describe, expect, it } from "vitest";
import { computeSajuChart, computeLuckCycles } from "./saju.js";
import { detectUngroundedSajuClaims, formatGroundingWarning } from "./factGrounding.js";
import type { BirthInfo } from "../types/index.js";

// 실제 엔진 출력을 근거 텍스트로 쓴다 (bot/evidence.ts buildNatalEvidence와 같은 방식).
const BIRTH: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const chart = computeSajuChart(BIRTH);
const luck = computeLuckCycles(BIRTH, new Date("2026-07-03T03:00:00Z"));
const EVIDENCE = `${JSON.stringify(chart)}\n${JSON.stringify(luck)}`;

describe("detectUngroundedSajuClaims — 신살", () => {
  it("근거에 없는 신살을 '네 사주에 있다'고 주장하면 감지한다", () => {
    // 1990-12-23 08:00 원국에 괴강은 없다 (임술 일주는 괴강 아님을 엔진 기준으로 확인)
    const hasGoegang = EVIDENCE.includes("괴강");
    if (hasGoegang) return; // 엔진이 괴강을 계산하면 이 픽스처는 무의미하므로 스킵
    const hits = detectUngroundedSajuClaims("네 사주에 괴강이 딱 있네. 그래서 카리스마가 강해.", EVIDENCE);
    expect(hits.some((h) => h.term === "괴강" && h.category === "sinsal")).toBe(true);
  });

  it("근거에 있는 신살 언급은 감지하지 않는다", () => {
    // 이 원국이 실제로 가진 신살 하나를 골라 주장 문장을 만든다
    const owned = (chart.sinsal ?? [])[0]?.name;
    if (!owned) return;
    const hits = detectUngroundedSajuClaims(`네 사주에 ${owned}이 있어.`, EVIDENCE);
    expect(hits.filter((h) => h.category === "sinsal")).toHaveLength(0);
  });

  it("이론 설명(정의문·조건문)은 근거에 없어도 감지하지 않는다", () => {
    const replies = [
      "괴강은 카리스마가 강한 리더 기질을 말하는 신살이야.",
      "사주에 괴강이 있으면 결단력이 강하다고 봐.",
      "예를 들어 사주에 백호가 있는 사람은 기세가 강해.",
    ];
    for (const reply of replies) {
      expect(detectUngroundedSajuClaims(reply, EVIDENCE)).toHaveLength(0);
    }
  });

  it("별칭을 인식한다: 엔진의 년살을 도화살로 불러도 grounded", () => {
    const evidenceWithYeonsal = EVIDENCE.includes("년살") ? EVIDENCE : `${EVIDENCE} {"name":"년살"}`;
    const hits = detectUngroundedSajuClaims("네 사주에 도화살이 있네.", evidenceWithYeonsal);
    expect(hits).toHaveLength(0);
  });
});

describe("detectUngroundedSajuClaims — 간지", () => {
  it("근거에 없는 간지를 일주라고 주장하면 감지한다", () => {
    // 실제 일주는 임술. 갑진은 시주라 근거에 있으니, 근거에 없는 간지를 골라 쓴다.
    const fake = ["을해", "정축", "신묘", "계미"].find((gz) => !EVIDENCE.includes(gz));
    expect(fake).toBeDefined();
    const hits = detectUngroundedSajuClaims(`네 일주가 ${fake}라서 그래.`, EVIDENCE);
    expect(hits.some((h) => h.term === fake && h.category === "ganzhi")).toBe(true);
  });

  it("실제 일주(임술) 언급은 감지하지 않는다", () => {
    const hits = detectUngroundedSajuClaims("네 일주가 임술이라 그래.", EVIDENCE);
    expect(hits).toHaveLength(0);
  });

  it("기둥 문맥이 없는 문장의 간지 유사 일상어(갑자기 등)는 무시한다", () => {
    const hits = detectUngroundedSajuClaims("갑자기 연락이 왔다고? 병신년 얘기 아니고.", EVIDENCE);
    expect(hits).toHaveLength(0);
  });

  it("기둥 문맥이 있어도 '갑자기'의 갑자는 제외한다", () => {
    const hits = detectUngroundedSajuClaims("네 일주 얘기하다가 갑자기 딴 데로 샜네.", EVIDENCE);
    expect(hits.filter((h) => h.term === "갑자")).toHaveLength(0);
  });
});

describe("detectUngroundedSajuClaims — 십성·격국", () => {
  it("'상관없다'류 일상어는 십성 상관으로 오탐하지 않는다", () => {
    const hits = detectUngroundedSajuClaims("그건 네 사주에 상관없이 있는 그대로 봐도 돼.", EVIDENCE);
    expect(hits.filter((h) => h.term === "상관")).toHaveLength(0);
  });

  it("근거에 없는 격국 주장(OO격)을 감지한다", () => {
    const gyeokName = chart.gyeokguk?.name ?? "";
    const fake = ["종살격", "곡직격", "염상격"].find((g) => g !== gyeokName && !EVIDENCE.includes(g));
    expect(fake).toBeDefined();
    const hits = detectUngroundedSajuClaims(`네 사주는 ${fake}으로 자리 잡혀 있어.`, EVIDENCE);
    expect(hits.some((h) => h.term === fake && h.category === "gyeokguk")).toBe(true);
  });

  it("성격·파격·합격 같은 일상어/판정어는 격국명으로 오탐하지 않는다", () => {
    const hits = detectUngroundedSajuClaims("네 사주엔 성격이 급한 기운이 있고, 시험 합격 운을 물었지.", EVIDENCE);
    expect(hits.filter((h) => h.category === "gyeokguk")).toHaveLength(0);
  });
});

describe("formatGroundingWarning", () => {
  it("감지가 없으면 null", () => {
    expect(formatGroundingWarning([])).toBeNull();
  });

  it("감지된 용어를 나열한 경고문을 만든다", () => {
    const warning = formatGroundingWarning([
      { term: "괴강", category: "sinsal", sentence: "네 사주에 괴강이 있네" },
    ]);
    expect(warning).toContain("괴강");
    expect(warning).toContain("확인되지 않아요");
  });
});
