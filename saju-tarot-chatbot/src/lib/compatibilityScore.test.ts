import { describe, expect, it } from "vitest";
import {
  computeCompatibility,
  computeSajuChart,
  dayMasterRelation,
  johuComplement,
  yongshinComplement,
} from "./saju.js";
import type { BirthInfo, SajuChart } from "../types/index.js";

// ── 단위 테스트: 순수 조합 함수 (노이즈 없이 이론 방향성 검증) ──────────

describe("dayMasterRelation — 음양·십성 세분화", () => {
  it("천간합이 가장 높다", () => {
    expect(dayMasterRelation("갑", "기").score).toBe(20); // 갑기합
  });
  it("음양이 갈리는 상극(정관·정재)이 음양이 같은 상극(편관·편재)보다 높다", () => {
    const govern = dayMasterRelation("갑", "신").score; // 목 vs 금, 음양 다름 → 정관/정재
    const clash = dayMasterRelation("갑", "경").score; // 목 vs 금, 음양 같음 → 편관/편재
    expect(govern).toBeGreaterThan(clash);
    expect(govern).toBe(18);
    expect(clash).toBe(10);
  });
  it("상생 관계는 중간, 같은 오행 비견/겁재는 낮은 편", () => {
    expect(dayMasterRelation("갑", "병").score).toBe(14); // 목생화
    expect(dayMasterRelation("갑", "갑").score).toBe(9); // 비견
    expect(dayMasterRelation("갑", "을").score).toBe(7); // 겁재
  });
  it("대칭: 순서를 바꿔도 같은 점수", () => {
    expect(dayMasterRelation("갑", "신").score).toBe(dayMasterRelation("신", "갑").score);
  });
});

// yongshin/johu는 chart.fiveElements + chart.yongshin만 읽으므로 최소 스텁으로 격리 테스트한다.
const stub = (
  fe: Partial<Record<"wood" | "fire" | "earth" | "metal" | "water", number>>,
  y: { yongshin?: string[]; heesin?: string[]; supportive?: string[]; climatic?: { element: string; note: string } | null },
): SajuChart =>
  ({
    fiveElements: { wood: 0, fire: 0, earth: 0, metal: 0, water: 0, ...fe },
    yongshin: { supportive: [], unfavorable: [], note: "", ...y },
  }) as unknown as SajuChart;

describe("yongshinComplement — 용신 기반 보완", () => {
  it("상대가 내 용신 오행을 넉넉히 가지면 보완 점수가 오른다", () => {
    const a = stub({ fire: 1, earth: 2, metal: 2 }, { yongshin: ["목"], supportive: ["목"] }); // 목 필요
    const b = stub({ wood: 3, fire: 1 }, { yongshin: ["화"], supportive: ["화"] }); // 목 넉넉
    const complement = yongshinComplement(a, b);
    const none = yongshinComplement(
      stub({ wood: 1, fire: 1, earth: 1, metal: 1, water: 1 }, { yongshin: ["목"], supportive: ["목"] }),
      stub({ wood: 1, fire: 1, earth: 1, metal: 1, water: 1 }, { yongshin: ["화"], supportive: ["화"] }), // 서로 아무것도 넉넉히 못 채움
    );
    expect(complement.score).toBeGreaterThan(none.score);
    expect(complement.score).toBeGreaterThanOrEqual(6);
    expect(complement.score).toBeLessThanOrEqual(20);
  });
  it("대칭", () => {
    const a = stub({ wood: 3 }, { yongshin: ["화"], supportive: ["화"] });
    const b = stub({ fire: 3 }, { yongshin: ["목"], supportive: ["목"] });
    expect(yongshinComplement(a, b).score).toBe(yongshinComplement(b, a).score);
  });
});

describe("johuComplement — 조후 보완", () => {
  it("상대가 내 조후 오행(화)을 채워주면 +", () => {
    const cold = stub({ water: 3 }, { climatic: { element: "화", note: "" } }); // 화 필요
    const warm = stub({ fire: 3 }, { climatic: null }); // 화 넉넉
    expect(johuComplement(cold, warm).score).toBeGreaterThan(0);
  });
  it("둘 다 같은 방향으로 치우치고 서로 못 채우면 -", () => {
    const coldA = stub({ water: 3 }, { climatic: { element: "화", note: "" } });
    const coldB = stub({ water: 3 }, { climatic: { element: "화", note: "" } });
    expect(johuComplement(coldA, coldB).score).toBeLessThan(0);
  });
  it("조후 신호가 없으면 0(중립)", () => {
    expect(johuComplement(stub({}, { climatic: null }), stub({}, { climatic: null })).score).toBe(0);
  });
});

// ── 통합 테스트: computeCompatibility ──────────

const baseBirth: BirthInfo = { calendarType: "solar", year: 1990, month: 5, day: 15, hour: 10, minute: 0, gender: "female" };
const otherBirth: BirthInfo = { calendarType: "solar", year: 1988, month: 11, day: 3, hour: 14, minute: 0, gender: "male" };

/** 조건을 만족하는 첫 생년월일을 찾는다(일지·일간 조합은 60일 주기 안에 모두 나타남). */
function findBirth(pred: (chart: SajuChart) => boolean, base = baseBirth): BirthInfo {
  const start = new Date(Date.UTC(1986, 0, 1));
  for (let i = 0; i < 70; i += 1) {
    const d = new Date(start.getTime() + i * 86400000);
    const birth: BirthInfo = { ...base, year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() };
    if (pred(computeSajuChart(birth))) return birth;
  }
  throw new Error("조건을 만족하는 생년월일을 찾지 못함");
}

const ZHI_LIUHE_PAIRS: Record<string, string> = { 자: "축", 인: "해", 묘: "술", 진: "유", 사: "신", 오: "미" };
const ZHI_CHONG_PAIRS: Record<string, string> = { 자: "오", 축: "미", 인: "신", 묘: "유", 진: "술", 사: "해" };

describe("computeCompatibility — 점수 불변식·이론 방향성", () => {
  it("대칭: A,B 순서를 바꿔도 총점 동일", () => {
    const ab = computeCompatibility(baseBirth, otherBirth, "romantic").score;
    const ba = computeCompatibility(otherBirth, baseBirth, "romantic").score;
    expect(ab).toBe(ba);
  });

  it("결정론: 같은 입력이면 같은 결과", () => {
    expect(computeCompatibility(baseBirth, otherBirth, "romantic").score).toBe(
      computeCompatibility(baseBirth, otherBirth, "romantic").score,
    );
  });

  it("총점은 0~100 범위", () => {
    for (const rel of ["romantic", "bossEmployee", "friend"] as const) {
      const s = computeCompatibility(baseBirth, otherBirth, rel).score;
      expect(s).toBeGreaterThanOrEqual(0);
      expect(s).toBeLessThanOrEqual(100);
    }
  });

  it("배우자궁: 일지 합 커플이 일지 충 커플보다 '연애·생활 자리' 점수가 높다", () => {
    const ref = computeSajuChart(baseBirth);
    const refZhi = ref.day.zhi;
    const heZhi = ZHI_LIUHE_PAIRS[refZhi] ?? Object.entries(ZHI_LIUHE_PAIRS).find(([, v]) => v === refZhi)?.[0];
    const chongZhi = ZHI_CHONG_PAIRS[refZhi] ?? Object.entries(ZHI_CHONG_PAIRS).find(([, v]) => v === refZhi)?.[0];
    if (!heZhi || !chongZhi) return; // 해당 일지에 합/충 짝이 정의 안 됐으면 스킵

    const hePartner = findBirth((c) => c.day.zhi === heZhi);
    const chongPartner = findBirth((c) => c.day.zhi === chongZhi);
    // breakdown[1] = 배우자궁(palace) 항목 (일지 관계에만 의존)
    const heScore = computeCompatibility(baseBirth, hePartner, "romantic").breakdown[1].score;
    const chongScore = computeCompatibility(baseBirth, chongPartner, "romantic").breakdown[1].score;
    expect(heScore).toBeGreaterThan(chongScore);
  });

  it("일간 천간합 커플은 '두 사람의 기질' 점수가 최상위", () => {
    const ref = computeSajuChart(baseBirth);
    const HE: Record<string, string> = { 갑: "기", 기: "갑", 을: "경", 경: "을", 병: "신", 신: "병", 정: "임", 임: "정", 무: "계", 계: "무" };
    const target = HE[ref.dayMasterGan];
    if (!target) return;
    const partner = findBirth((c) => c.dayMasterGan === target);
    const temperScore = computeCompatibility(baseBirth, partner, "romantic").breakdown[0].score;
    expect(temperScore).toBe(100); // dm.score 20 → (20/20)*100
  });

  it("표면 문장(summary·breakdown note)에 사주 용어를 노출하지 않는다", () => {
    const result = computeCompatibility(baseBirth, otherBirth, "romantic");
    const surface = [result.summary, ...result.breakdown.map((b) => b.note)].join(" ");
    for (const term of ["십성", "용신", "조후", "편관", "정관", "편재", "정재", "일지", "천간", "지지", "신강", "신약"]) {
      expect(surface).not.toContain(term);
    }
  });
});

// ── C-1: 궁합 교차 타이밍 상세 (timingDetail) — 점수 불변·구조·톤 ──────────

describe("computeCompatibility.timingDetail — C-1 교차 타이밍", () => {
  it("timingDetail은 항상 채워지고, 점수는 그대로 결정론적이다(점수 불변식)", () => {
    const r1 = computeCompatibility(baseBirth, otherBirth, "romantic");
    const r2 = computeCompatibility(baseBirth, otherBirth, "romantic");
    expect(r1.timingDetail).toBeDefined();
    // 새 필드가 추가돼도 점수는 두 번 계산이 동일해야 한다.
    expect(r1.score).toBe(r2.score);
    // 전체 timingDetail도 결정론적.
    expect(JSON.stringify(r1.timingDetail)).toBe(JSON.stringify(r2.timingDetail));
  });

  it("outlook은 최대 3년, 연도는 오름차순, tone은 3종 중 하나", () => {
    const td = computeCompatibility(baseBirth, otherBirth, "romantic").timingDetail!;
    expect(td.outlook.length).toBeGreaterThanOrEqual(1);
    expect(td.outlook.length).toBeLessThanOrEqual(3);
    for (let i = 1; i < td.outlook.length; i += 1) {
      expect(td.outlook[i].year).toBeGreaterThan(td.outlook[i - 1].year);
    }
    for (const o of td.outlook) {
      expect(["순한 편", "무난한 편", "조율이 필요한 편"]).toContain(o.tone);
    }
  });

  it("crossHits kind/valence 일관성(합=good, 충·형·파·해=bad)", () => {
    const td = computeCompatibility(baseBirth, otherBirth, "romantic").timingDetail!;
    for (const c of td.crossHits) {
      expect(["합", "충", "형", "파", "해"]).toContain(c.kind);
      expect(c.valence).toBe(c.kind === "합" ? "good" : "bad");
      expect(c.plain.length).toBeGreaterThan(0);
      expect(c.mover.length).toBeGreaterThan(0);
      expect(c.target.length).toBeGreaterThan(0);
    }
  });

  it("dayunPhase.sync는 두 사람 대운 favor와 규칙이 맞는다(S-4 favor 재사용)", () => {
    const td = computeCompatibility(baseBirth, otherBirth, "romantic").timingDetail!;
    const { aFavor, bFavor, sync } = td.dayunPhase;
    if (aFavor === "boost" && bFavor === "boost") expect(sync).toBe("aligned-good");
    else if (aFavor === "drain" && bFavor === "drain") expect(sync).toBe("aligned-hard");
    else if ((aFavor === "boost" && bFavor === "drain") || (aFavor === "drain" && bFavor === "boost"))
      expect(sync).toBe("diverging");
    else expect(sync).toBe("neutral");
    expect(td.dayunPhase.headline.length).toBeGreaterThan(0);
  });

  it("표면 문장(dayunPhase.headline·outlook.body·tone·crossHits.plain)에 사주 용어를 노출하지 않는다", () => {
    const td = computeCompatibility(baseBirth, otherBirth, "romantic").timingDetail!;
    const surface = [
      td.dayunPhase.headline,
      ...td.outlook.map((o) => `${o.tone} ${o.body}`),
      ...td.crossHits.map((c) => c.plain),
    ].join(" ");
    // 간지·자리명·용어는 evidence 전용이므로 표면 문자열엔 없어야 한다.
    // (합/충/형/파/해 단일 글자는 '해예요' 등 일상어와 겹쳐 substring 검사 대상에서 제외 — 기존 컨벤션 동일)
    for (const term of ["세운", "대운", "용신", "기신", "조후", "일지", "월지", "천간", "지지", "신강", "신약"]) {
      expect(surface).not.toContain(term);
    }
  });
});
