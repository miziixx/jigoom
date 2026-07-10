import { describe, expect, it } from "vitest";
import { computeSajuChart, computeLuckCycles, computeCompatibility } from "./saju.js";
import type { BirthInfo } from "../types/index.js";

const female1990: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };

describe("신살 계산", () => {
  const chart = computeSajuChart(female1990);

  it("일주 임술은 백호·괴강 신살을 함께 가진다", () => {
    // 임술 일주는 백호대살(임술)이면서 괴강(임술)에 해당
    const names = chart.sinsal!.map((s) => s.name);
    expect(names).toContain("백호대살");
    expect(names).toContain("괴강");
  });

  it("십이신살을 일지 삼합국 기준으로 계산한다 (임술=화1990국)", () => {
    // 원국 경오 무자 임술 갑진 — 일지 술(인오술 火局): 오=장성살, 자=재살, 술=화개살, 진=월살
    const map = new Map((chart.sinsal ?? []).map((s) => [`${s.name}|${s.position}`, true]));
    expect(map.has("장성살|연지 오")).toBe(true);
    expect(map.has("재살|월지 자")).toBe(true);
    expect(map.has("화개살|일지 술")).toBe(true);
    expect(map.has("월살|시지 진")).toBe(true);
  });

  it("원진·귀문 지지쌍과 년살(도화)을 계산한다 (을축 임오 을유 계미)", () => {
    const c = computeSajuChart({ calendarType: "solar", year: 1985, month: 6, day: 15, hour: 14, minute: 0, gender: "female" });
    const names = (c.sinsal ?? []).map((s) => s.name);
    // 일지 유(사유축 金局): 오=년살(도화), 유=장성살, 축=화개살
    expect(names).toContain("년살");
    expect(names).toContain("장성살");
    // 연지 축–월지 오가 함께 있어 원진·귀문 성립
    expect(names).toContain("원진살");
    expect(names).toContain("귀문관살");
  });

  it("모든 신살 이름은 알려진 신살 집합 안에 있다", () => {
    const KNOWN = new Set([
      "겁살", "재살", "천살", "지살", "년살", "월살", "망신살", "장성살", "반안살", "역마살", "육해살", "화개살",
      "천을귀인", "천덕귀인", "월덕귀인", "양인", "문창귀인", "학당귀인", "금여", "암록", "홍염살",
      "백호대살", "괴강", "원진살", "귀문관살", "고신살", "과숙살",
      "태극귀인", "천상삼기", "지하삼기", "인중삼기", "관귀학관", "재고귀인", "격각살",
      "복성귀인", "현침살", "상문살", "조객살",
    ]);
    for (const s of chart.sinsal ?? []) expect(KNOWN.has(s.name)).toBe(true);
  });

  it("모든 신살 항목은 이름·위치·뜻을 갖는다", () => {
    for (const s of chart.sinsal ?? []) {
      expect(s.name.length).toBeGreaterThan(0);
      expect(s.position.length).toBeGreaterThan(0);
      expect(s.gloss.length).toBeGreaterThan(0);
    }
  });

  it("천을귀인은 일간 기준 정해진 지지에만 잡힌다", () => {
    // 갑일간 + 축 지지 → 천을귀인
    const chart2 = computeSajuChart({ calendarType: "solar", year: 1984, month: 2, day: 5, hour: 2, gender: "male" });
    // 존재 여부와 무관하게, 천을귀인이 잡혔다면 위치 지지가 축/미 중 하나여야 함
    const cheoneul = (chart2.sinsal ?? []).filter((s) => s.name === "천을귀인");
    for (const s of cheoneul) {
      const dayGan = chart2.dayMasterGan;
      if (dayGan === "갑" || dayGan === "무" || dayGan === "경") {
        expect(s.position).toMatch(/[축미]/);
      }
    }
  });
});

describe("격국·희신", () => {
  const chart = computeSajuChart(female1990);
  it("격국이 판정된다", () => {
    expect(chart.gyeokguk).toBeDefined();
    expect(chart.gyeokguk!.name.length).toBeGreaterThan(0);
    expect(chart.gyeokguk!.basis).toContain("월지");
  });
  it("신강/신약이면 용신과 희신이 분리된다", () => {
    const weak = computeSajuChart({ calendarType: "solar", year: 1975, month: 6, day: 15, hour: 12, gender: "female" });
    if (weak.strength!.label !== "중화") {
      expect(weak.yongshin!.yongshin!.length).toBeGreaterThan(0);
      expect(weak.yongshin!.heesin!.length).toBeGreaterThan(0);
      // 용신과 희신은 겹치지 않아야 함
      for (const h of weak.yongshin!.heesin!) expect(weak.yongshin!.yongshin!).not.toContain(h);
    }
  });
  it("격국에 성패(성격/파격/불명확) 판정이 붙는다", () => {
    expect(["성격 경향", "파격 경향", "불명확"]).toContain(chart.gyeokguk!.status);
    expect(chart.gyeokguk!.statusReason!.length).toBeGreaterThan(0);
  });
  it("용신에 관법 요약(method)이 붙고, 여름/겨울생이면 조후용신이 잡힌다", () => {
    // 1985-06-15은 임오월(여름) → 조후 수
    const summer = computeSajuChart({ calendarType: "solar", year: 1985, month: 6, day: 15, hour: 14, gender: "female" });
    expect(summer.yongshin!.method).toContain("억부");
    expect(summer.yongshin!.climatic).toBeTruthy();
    expect(summer.yongshin!.climatic!.element).toBe("수");
    // 겨울생(자월)이면 조후 화
    const winter = computeSajuChart({ calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, gender: "female" });
    expect(winter.yongshin!.climatic!.element).toBe("화");
  });
});

describe("대운·세운 중첩", () => {
  it("현재 대운이 있으면 중첩 판정을 계산한다", () => {
    const chart = computeSajuChart(female1990);
    const luck = computeLuckCycles(female1990, new Date("2026-07-03T03:00:00Z"), {
      yongElements: chart.yongshin!.supportive,
      avoidElements: chart.yongshin!.unfavorable,
    });
    if (luck.currentDaYun) {
      expect(luck.daYunYearOverlap).toBeDefined();
      const o = luck.daYunYearOverlap!;
      expect(o.yearGanZhi).toBe(luck.yearGanZhi);
      expect(o.daYunGanZhi).toBe(luck.currentDaYun);
      expect(["amplify-good", "amplify-bad", "mixed", "quiet"]).toContain(o.combo);
      expect(["boost", "drain", "neutral"]).toContain(o.daYunFavor);
      expect(o.headline.length).toBeGreaterThan(0);
      expect(o.evidence.length).toBeGreaterThan(0);
      // 표면 headline에 십성/충합 용어를 그대로 노출하지 않는다
      for (const term of ["편재", "정관", "식신", "비견"]) expect(o.headline).not.toContain(term);
    }
  });

  it("용신 오행을 주지 않으면 방향은 중립으로 계산된다", () => {
    const luck = computeLuckCycles(female1990, new Date("2026-07-03T03:00:00Z"));
    if (luck.daYunYearOverlap) {
      expect(luck.daYunYearOverlap.daYunFavor).toBe("neutral");
      expect(luck.daYunYearOverlap.yearFavor).toBe("neutral");
      expect(luck.daYunYearOverlap.combo).toBe("quiet");
    }
  });
});

describe("통근·투출", () => {
  const chart = computeSajuChart(female1990); // 경오 무자 임술 갑진
  it("각 천간의 통근을 계산한다", () => {
    expect(chart.rootedness).toBeDefined();
    // 일간(임수)에 대한 통근 판정이 존재한다
    const day = chart.rootedness!.find((r) => r.position === "일간");
    expect(day).toBeTruthy();
    expect(day!.gan).toBe("임");
    // 임수는 자(연지 아래... 실제로는 월지 자)에 정기 통근
    const hasWaterRoot = day!.roots.some((r) => r.zhi === "자");
    expect(hasWaterRoot).toBe(true);
    expect(day!.note.length).toBeGreaterThan(0);
  });
  it("뿌리 없는 천간은 rooted=false로 표시된다", () => {
    for (const r of chart.rootedness!) {
      expect(r.rooted).toBe(r.roots.length > 0);
    }
  });
  it("월지 지장간의 투출 여부를 계산한다", () => {
    expect(chart.transparency).toBeDefined();
    expect(chart.transparency!.monthZhi).toBe("자");
    expect(chart.transparency!.hidden.length).toBeGreaterThan(0);
    expect(chart.transparency!.note.length).toBeGreaterThan(0);
  });
});

describe("60갑자 일주 성향", () => {
  it("일주에 맞는 성향 문구가 붙는다", () => {
    const chart = computeSajuChart(female1990);
    expect(chart.iljuTrait).toBeDefined();
    expect(chart.iljuTrait!.length).toBeGreaterThan(5);
  });
});

describe("세운 다년", () => {
  const luck = computeLuckCycles(female1990, new Date("2026-07-03T03:00:00Z"));
  it("올해부터 10년치 세운을 만든다", () => {
    expect(luck.yearlyFlow).toHaveLength(10);
    expect(luck.yearlyFlow![0].year).toBe(2026);
    expect(luck.yearlyFlow![0].current).toBe(true);
    expect(luck.yearlyFlow![9].year).toBe(2035);
  });
  it("나이가 연도에 따라 증가한다", () => {
    const ages = luck.yearlyFlow!.map((y) => y.age);
    for (let i = 1; i < ages.length; i++) expect(ages[i]).toBe(ages[i - 1] + 1);
  });
});

describe("세운 상문·조객 (엔진 업그레이드 S-3)", () => {
  // 원국 년지 오(午) → 상문살 = 년지+2 = 신(申), 조객살 = 년지-2 = 진(辰)
  const chart = computeSajuChart(female1990);
  const luck = computeLuckCycles(female1990, new Date("2026-07-03T03:00:00Z"));

  it("원국 년지 기준 상문(+2)·조객(-2) 자리에 오는 세운에만 신살이 붙는다", () => {
    const idx = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"];
    const yi = idx.indexOf(chart.year.zhi);
    const sangmun = idx[(yi + 2) % 12];
    const jogaek = idx[(yi + 10) % 12];

    for (const yf of luck.yearlyFlow!) {
      const zhi = yf.ganZhi[1];
      if (zhi === sangmun) expect(yf.sinsalHits).toEqual(["상문살"]);
      else if (zhi === jogaek) expect(yf.sinsalHits).toEqual(["조객살"]);
      else expect(yf.sinsalHits).toBeUndefined();
    }
  });

  it("10년 창(지지 12주기 미만)에서 상문·조객은 각각 최대 한 번만 나타난다", () => {
    const flat = luck.yearlyFlow!.flatMap((yf) => yf.sinsalHits ?? []);
    expect(flat.filter((s) => s === "상문살").length).toBeLessThanOrEqual(1);
    expect(flat.filter((s) => s === "조객살").length).toBeLessThanOrEqual(1);
    // female1990(년지 오)는 10년 창에 상문(신)이 한 번 든다
    expect(flat).toContain("상문살");
  });

  it("결정론: 같은 입력은 같은 세운 신살 배치를 낸다", () => {
    const again = computeLuckCycles(female1990, new Date("2026-07-03T03:00:00Z"));
    expect(again.yearlyFlow!.map((y) => y.sinsalHits)).toEqual(luck.yearlyFlow!.map((y) => y.sinsalHits));
  });
});

describe("윤달·야자시", () => {
  it("윤달 여부에 따라 다른 원국이 나온다", () => {
    // 1987년은 음력 윤6월이 있는 해
    const normal = computeSajuChart({ calendarType: "lunar", year: 1987, month: 6, day: 15, hour: 12, gender: "male" });
    const leap = computeSajuChart({ calendarType: "lunar", year: 1987, month: 6, day: 15, hour: 12, gender: "male", isLeapMonth: true });
    expect(normal.month.ganZhi).not.toBe(leap.month.ganZhi);
  });

  it("23시 출생의 조자시/야자시는 일주가 달라진다", () => {
    const base = { calendarType: "solar" as const, year: 2000, month: 1, day: 1, hour: 23, minute: 30, gender: "male" as const };
    const late = computeSajuChart({ ...base, lateNightZi: "late" }); // 당일 일주
    const early = computeSajuChart({ ...base, lateNightZi: "early" }); // 다음날 일주
    expect(late.day.ganZhi).not.toBe(early.day.ganZhi);
  });
});

describe("궁합 계산", () => {
  const A = female1990;
  const B: BirthInfo = { calendarType: "solar", year: 1988, month: 5, day: 5, hour: 14, minute: 0, gender: "male" };
  const compat = computeCompatibility(A, B);

  it("0~100 점수와 세부 항목을 낸다", () => {
    expect(compat.score).toBeGreaterThanOrEqual(0);
    expect(compat.score).toBeLessThanOrEqual(100);
    expect(compat.breakdown.length).toBeGreaterThanOrEqual(4);
    expect(compat.dayMasterRelation.length).toBeGreaterThan(0);
    expect(compat.summary.length).toBeGreaterThan(0);
    expect(compat.partnerPalace?.body.length).toBeGreaterThan(0);
    expect(compat.roleChemistry).toHaveLength(2);
    expect(compat.purposeFits).toHaveLength(4);
    expect(compat.timing).toHaveLength(2);
    expect(compat.repairReport?.conflictCycle.length).toBeGreaterThanOrEqual(4);
    expect(compat.repairReport?.byPerson.me.length).toBeGreaterThanOrEqual(3);
    expect(compat.repairReport?.byPerson.partner.length).toBeGreaterThanOrEqual(3);
    expect(compat.repairReport?.scripts.length).toBeGreaterThanOrEqual(3);
    expect(compat.solutionPlan?.todayActions.length).toBeGreaterThanOrEqual(3);
    expect(compat.solutionPlan?.weekActions.length).toBeGreaterThanOrEqual(3);
  });

  it("세부 흐름·목적별 궁합에 '이럴 때 드러나요' 신호와 상세를 담는다", () => {
    for (const b of compat.breakdown) {
      expect(b.detail && b.detail.length).toBeGreaterThan(0);
      expect(b.signal && b.signal.length).toBeGreaterThan(0);
    }
    for (const fit of compat.purposeFits ?? []) {
      expect(fit.signal && fit.signal.length).toBeGreaterThan(0);
    }
  });

  it("종합 요약이 가장 강한 축을 구체적으로 짚는다", () => {
    const strongest = [...compat.breakdown].sort((x, y) => y.score - x.score)[0];
    expect(compat.summary).toContain(strongest.label);
  });

  it("교환해도 점수가 동일하다 (대칭성)", () => {
    const swapped = computeCompatibility(B, A);
    expect(swapped.score).toBe(compat.score);
  });

  it("관계 유형별 궁합 문맥을 바꿀 수 있다", () => {
    const family = computeCompatibility(A, B, "parentChild");
    const work = computeCompatibility(A, B, "bossEmployee");
    const friend = computeCompatibility(A, B, "friend");
    const rival = computeCompatibility(A, B, "rival");
    expect(family.relationLabel).toBe("부모와 자식");
    expect(JSON.stringify(family.solutionPlan)).toContain("가족");
    expect(JSON.stringify(family.solutionPlan)).toContain("돌봄");
    expect(work.purposeFits?.map((p) => p.label)).toContain("지시·보고");
    expect(work.breakdown.map((b) => b.label)).toContain("업무·책임 자리");
    expect(JSON.stringify(work.purposeFits)).toContain("지시");
    expect(JSON.stringify(work.purposeFits)).not.toContain("데이트");
    expect(JSON.stringify(friend.solutionPlan)).toContain("부탁");
    expect(JSON.stringify(friend.solutionPlan)).toContain("친");
    expect(rival.improvementTips?.join(" ")).toContain("사실");
  });

  it("사장·직원 궁합은 역할 라벨을 결과에 보존한다", () => {
    const bossEmployee = computeCompatibility(A, B, "bossEmployee", "사장과 직원으로 잘 맞나요?", { first: "나(사장)", second: "상대(직원)" });
    expect(bossEmployee.people?.map((p) => p.label)).toEqual(["나(사장)", "상대(직원)"]);
    expect(bossEmployee.roleChemistry?.[0].title).toContain("나(사장)");
    expect(bossEmployee.roleChemistry?.[0].title).toContain("상대(직원)");
    expect(bossEmployee.solutionPlan?.relationshipContext).toContain("상대(직원)");
  });

  it("궁합 질문을 넣으면 질문 의도와 현실 행동을 따로 만든다", () => {
    const withQuestion = computeCompatibility(A, B, "coworker", "이 사람과 같이 일해도 괜찮을까요?");
    expect(withQuestion.questionInsight?.question).toContain("같이 일");
    expect(withQuestion.questionInsight?.intent).toContain("역할");
    expect(withQuestion.questionInsight?.answer.length).toBeGreaterThan(0);
    expect(withQuestion.questionInsight?.signals.length).toBeGreaterThanOrEqual(3);
    expect(withQuestion.questionInsight?.actions.length).toBeGreaterThanOrEqual(3);
    expect(withQuestion.solutionPlan?.problem).toContain("같이 일");
    expect(withQuestion.solutionPlan?.personalContext).toContain("나는");
    expect(withQuestion.solutionPlan?.relationshipContext).toContain("상대");
    expect(withQuestion.solutionPlan?.scripts.length).toBeGreaterThanOrEqual(3);
    expect(withQuestion.solutionPlan?.checkSignals.length).toBeGreaterThanOrEqual(3);
  });

  it("관계 맞춤 솔루션은 사주 조합에 따라 달라진다", () => {
    const anotherA: BirthInfo = { calendarType: "solar", year: 1995, month: 3, day: 18, hour: 22, minute: 15, gender: "female" };
    const first = computeCompatibility(A, B, "romantic", "이 사람과 계속 만나도 될까요?");
    const second = computeCompatibility(anotherA, B, "romantic", "이 사람과 계속 만나도 될까요?");
    expect(second.solutionPlan?.personalContext).not.toBe(first.solutionPlan?.personalContext);
    expect(second.solutionPlan?.todayActions.join(" ")).not.toBe(first.solutionPlan?.todayActions.join(" "));
  });

  it("결과 표면 문장에 사주 전문용어가 없다", () => {
    // 단독 '충/형/파/해'는 '균형' 등 일반어와 겹쳐 오탐이므로, 명확한 용어만 검사
    const JARGON = ["천간합", "육합", "삼합", "반합", "상생", "상극", "비화", "오행", "일간", "십성", "지지 관계", "지지 사이"];
    const surface = JSON.stringify({
      dayMasterRelation: compat.dayMasterRelation,
      branchRelations: compat.branchRelations,
      elementComplement: compat.elementComplement,
      summary: compat.summary,
      breakdown: compat.breakdown,
      partnerPalace: compat.partnerPalace?.body,
      roleChemistry: compat.roleChemistry?.map((r) => r.body),
      purposeFits: compat.purposeFits,
      timing: compat.timing?.map((t) => t.body),
      repairReport: compat.repairReport,
      solutionPlan: compat.solutionPlan,
    });
    for (const w of JARGON) expect(surface, `궁합에 용어 노출: ${w}`).not.toContain(w);
  });
});
