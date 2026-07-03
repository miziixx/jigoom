import { Solar } from "lunar-javascript";
import {
  ELEMENT_KO,
  GAN_WUXING,
  ZHI_WUXING,
  computeSajuChart,
  gongmangOf,
  tenGodOf,
  toHangul,
  twelveStageOf,
} from "./saju.js";
import type {
  BirthInfo,
  BranchRelationHit,
  BranchRelationKind,
  FiveElementBalance,
  FortuneCategoryScores,
  FortuneEvidence,
  TenGodGroup,
} from "../types/index.js";

// ──────────────────────────────────────────────────────────────
// Asia/Seoul 기준 "오늘"
// 일진 간지는 자정(00:00)에 바뀌므로(라이브러리 검증 완료), KST 정오로 계산하면
// 시각 경계와 무관하게 그 날짜의 일진이 확정된다.
// ──────────────────────────────────────────────────────────────

const WEEKDAYS = ["일", "월", "화", "수", "목", "금", "토"];

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

export interface KstDate {
  year: number;
  month: number;
  day: number;
  iso: string;
  weekday: string;
}

/** UTC 기준 시각을 Asia/Seoul(UTC+9) 민간 날짜로 변환한다 (서버 TZ와 무관). */
export function kstDateOf(now: Date = new Date()): KstDate {
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const year = kst.getUTCFullYear();
  const month = kst.getUTCMonth() + 1;
  const day = kst.getUTCDate();
  return {
    year,
    month,
    day,
    iso: `${year}-${pad2(month)}-${pad2(day)}`,
    weekday: WEEKDAYS[kst.getUTCDay()],
  };
}

/** KST 날짜의 일진/월운/세운 간지(한글)를 계산한다. */
export function ganzhiForKstDate(kst: KstDate): { day: string; month: string; year: string } {
  const lunar = Solar.fromYmdHms(kst.year, kst.month, kst.day, 12, 0, 0).getLunar();
  return {
    day: toHangul(lunar.getDayInGanZhi()),
    month: toHangul(lunar.getMonthInGanZhi()),
    year: toHangul(lunar.getYearInGanZhiByLiChun()),
  };
}

// ──────────────────────────────────────────────────────────────
// 십성 5분류
// ──────────────────────────────────────────────────────────────

const TEN_GOD_GROUP: Record<string, TenGodGroup> = {
  비견: "비겁",
  겁재: "비겁",
  식신: "식상",
  상관: "식상",
  편재: "재성",
  정재: "재성",
  편관: "관성",
  정관: "관성",
  편인: "인성",
  정인: "인성",
};

const TEN_GOD_AXIS: Record<TenGodGroup, string> = {
  비겁: "경쟁·협력·자기 주도가 부각되는 흐름 (내 힘을 쓰거나 나눠 써야 하는 날)",
  식상: "표현·활동·아이디어가 밖으로 나가는 흐름 (말·콘텐츠·생산이 늘기 쉬운 날)",
  재성: "현실·성과·재물이 중심에 오는 흐름 (돈·결과·실무를 다루기 좋은 날)",
  관성: "책임·규율·평가가 들어오는 흐름 (일·직책·규칙과 부딪히거나 인정받는 날)",
  인성: "학습·수용·지원·휴식이 들어오는 흐름 (배우고 채우고 기대게 되는 날)",
};

export function tenGodGroupOf(name: string): TenGodGroup {
  return TEN_GOD_GROUP[name] ?? "비겁";
}

// ──────────────────────────────────────────────────────────────
// 지지 관계 (육합/삼합/방합/충/형/파/해/원진) — 오늘 지지 vs 내 지지 pairwise
// ──────────────────────────────────────────────────────────────

const ZHI_LIUHE = new Set(["자축", "축자", "인해", "해인", "묘술", "술묘", "진유", "유진", "사신", "신사", "오미", "미오"]);
const ZHI_CHONG = new Set(["자오", "오자", "축미", "미축", "인신", "신인", "묘유", "유묘", "진술", "술진", "사해", "해사"]);
// 형: 인사신 삼형 · 축술미 삼형 · 자묘 상형 (자형은 같은 글자, 아래에서 별도 처리)
const ZHI_XING = new Set([
  "인사", "사인", "사신", "신사", "인신", "신인",
  "축술", "술축", "술미", "미술", "축미", "미축",
  "자묘", "묘자",
]);
const ZHI_SELF_XING = new Set(["진", "오", "유", "해"]);
const ZHI_PO = new Set(["자유", "유자", "축진", "진축", "인해", "해인", "묘오", "오묘", "사신", "신사", "술미", "미술"]);
const ZHI_HAI = new Set(["자미", "미자", "축오", "오축", "인사", "사인", "묘진", "진묘", "신해", "해신", "유술", "술유"]);
const ZHI_YUANJIN = new Set(["자미", "미자", "축오", "오축", "인유", "유인", "묘신", "신묘", "진해", "해진", "사술", "술사"]);

// 삼합(반합 포함) / 방합 그룹
const SANHE_GROUPS: string[][] = [
  ["인", "오", "술"],
  ["사", "유", "축"],
  ["신", "자", "진"],
  ["해", "묘", "미"],
];
const FANGHE_GROUPS: string[][] = [
  ["인", "묘", "진"],
  ["사", "오", "미"],
  ["신", "유", "술"],
  ["해", "자", "축"],
];

// 사왕지 — 반합/부분방합은 왕지(子午卯酉)가 있을 때만 성립으로 본다 (표준 반합 규칙)
const WANGJI = new Set(["자", "오", "묘", "유"]);

function partialCombo(groups: string[][], a: string, b: string): boolean {
  if (a === b) return false;
  return groups.some((g) => g.includes(a) && g.includes(b) && (WANGJI.has(a) || WANGJI.has(b)));
}

/** 두 지지가 맺는 모든 관계를 반환한다 (없으면 빈 배열). */
export function branchRelationsBetween(mine: string, today: string): BranchRelationKind[] {
  const rel: BranchRelationKind[] = [];
  const key = mine + today;
  if (ZHI_LIUHE.has(key)) rel.push("육합");
  if (partialCombo(SANHE_GROUPS, mine, today)) rel.push("삼합");
  if (partialCombo(FANGHE_GROUPS, mine, today)) rel.push("방합");
  if (ZHI_CHONG.has(key)) rel.push("충");
  if (ZHI_XING.has(key)) rel.push("형");
  else if (mine === today && ZHI_SELF_XING.has(mine)) rel.push("형");
  if (ZHI_PO.has(key)) rel.push("파");
  if (ZHI_HAI.has(key)) rel.push("해");
  if (ZHI_YUANJIN.has(key)) rel.push("원진");
  return rel;
}

// 관계별 길흉 방향값 (합=순, 충/형/원진=변동, 파/해=마찰)
const KIND_DIRECTION: Record<BranchRelationKind, number> = {
  육합: 0.7,
  삼합: 0.8,
  방합: 0.6,
  충: -0.9,
  형: -0.6,
  원진: -0.6,
  파: -0.3,
  해: -0.3,
};

// 자리 가중치 (일지가 가장 큼 — 나 자신·일상·배우자 자리)
const POSITION_WEIGHT: Record<string, number> = { 연지: 1, 월지: 2, 일지: 3, 시지: 1.5 };

const REL_LABEL: Record<BranchRelationKind, string> = {
  육합: "합(순조·협력)",
  삼합: "삼합(강한 결속)",
  방합: "방합(같은 계절 결속)",
  충: "충(변동·충돌)",
  형: "형(마찰·조정)",
  원진: "원진(까닭 모를 불편)",
  파: "파(깨짐·엇갈림)",
  해: "해(방해·거슬림)",
};

function directionOf(relations: BranchRelationKind[]): number {
  const sum = relations.reduce((acc, r) => acc + KIND_DIRECTION[r], 0);
  return Math.max(-1, Math.min(1, sum));
}

interface PositionedBranch {
  position: string;
  branch: string;
}

function computeBranchRelations(mineBranches: PositionedBranch[], todayZhi: string): BranchRelationHit[] {
  return mineBranches.map(({ position, branch }) => {
    const relations = branchRelationsBetween(branch, todayZhi);
    const weight = POSITION_WEIGHT[position] ?? 1;
    const direction = directionOf(relations);
    const detail =
      relations.length > 0
        ? `${position} ${branch} ↔ 오늘 ${todayZhi}: ${relations.map((r) => REL_LABEL[r]).join(", ")}`
        : `${position} ${branch} ↔ 오늘 ${todayZhi}: 특별한 관계 없음`;
    return { position, myBranch: branch, todayBranch: todayZhi, relations, weight, direction, detail };
  });
}

// ──────────────────────────────────────────────────────────────
// 오행 조력도 (-100 ~ +100)
// ──────────────────────────────────────────────────────────────

function elementKoOfGan(gan: string): string {
  return ELEMENT_KO[GAN_WUXING[gan]];
}
function elementKoOfZhi(zhi: string): string {
  return ELEMENT_KO[ZHI_WUXING[zhi]];
}

function computeElementSupport(
  dayGan: string,
  dayZhi: string,
  yongshin: string[],
  gishin: string[],
): FortuneEvidence["elementSupport"] {
  const ganEl = elementKoOfGan(dayGan);
  const zhiEl = elementKoOfZhi(dayZhi);
  const units = [ganEl, zhiEl];
  const todayElements = Array.from(new Set(units));

  let score = 0;
  for (const el of units) {
    if (yongshin.includes(el)) score += 50;
    else if (gishin.includes(el)) score -= 50;
  }
  score = Math.max(-100, Math.min(100, score));

  const helpsYongshin = units.some((el) => yongshin.includes(el));
  const strengthensGishin = units.some((el) => gishin.includes(el));

  const detail = `오늘 오행 ${todayElements.join("·")} vs 용신 후보 ${yongshin.join("·") || "없음"}${
    gishin.length ? ` / 기신 후보 ${gishin.join("·")}` : ""
  } → 조력 ${score > 0 ? "+" : ""}${score}`;

  return { todayElements, score, helpsYongshin, strengthensGishin, detail };
}

// ──────────────────────────────────────────────────────────────
// 12운성 에너지 레벨
// ──────────────────────────────────────────────────────────────

const STAGE_ENERGY: Record<string, number> = {
  장생: 78,
  목욕: 58,
  관대: 72,
  건록: 88,
  제왕: 100,
  쇠: 55,
  병: 42,
  사: 28,
  묘: 32,
  절: 22,
  태: 45,
  양: 62,
};

// ──────────────────────────────────────────────────────────────
// 신살 (천을귀인 / 역마 / 도화 / 화개 / 공망)
// ──────────────────────────────────────────────────────────────

// 천을귀인: 일간 기준 귀인 지지 (甲戊庚牛羊 / 乙己鼠猴 / 丙丁豬雞 / 六辛逢虎馬 / 壬癸兔蛇)
const CHEONEUL_GWIIN: Record<string, string[]> = {
  갑: ["축", "미"],
  무: ["축", "미"],
  경: ["축", "미"],
  을: ["자", "신"],
  기: ["자", "신"],
  병: ["해", "유"],
  정: ["해", "유"],
  신: ["인", "오"],
  임: ["묘", "사"],
  계: ["묘", "사"],
};

// 삼합 그룹 기준 도화/역마/화개 (기준 지지가 속한 삼합국으로 판정)
const GROUP_SINSAL: Array<{ group: string[]; dohwa: string; yeongma: string; hwagae: string }> = [
  { group: ["신", "자", "진"], dohwa: "유", yeongma: "인", hwagae: "진" },
  { group: ["인", "오", "술"], dohwa: "묘", yeongma: "신", hwagae: "술" },
  { group: ["사", "유", "축"], dohwa: "오", yeongma: "해", hwagae: "축" },
  { group: ["해", "묘", "미"], dohwa: "자", yeongma: "사", hwagae: "미" },
];

function sinsalTargetsFor(refBranch: string): { dohwa: string; yeongma: string; hwagae: string } | null {
  return GROUP_SINSAL.find((g) => g.group.includes(refBranch)) ?? null;
}

function computeSinsal(
  dayMaster: string,
  todayZhi: string,
  refBranches: string[],
  gongmangZhis: string,
): FortuneEvidence["sinsal"] {
  const cheoneulgwiin = (CHEONEUL_GWIIN[dayMaster] ?? []).includes(todayZhi);

  let dohwa = false;
  let yeongma = false;
  let hwagae = false;
  for (const ref of refBranches) {
    const t = sinsalTargetsFor(ref);
    if (!t) continue;
    if (t.dohwa === todayZhi) dohwa = true;
    if (t.yeongma === todayZhi) yeongma = true;
    if (t.hwagae === todayZhi) hwagae = true;
  }

  const gongmang = gongmangZhis.includes(todayZhi);

  const hits: string[] = [];
  if (cheoneulgwiin) hits.push("천을귀인 (귀인의 도움을 받기 쉬움)");
  if (yeongma) hits.push("역마 (이동·출장·변동 기운)");
  if (dohwa) hits.push("도화 (매력·인기·관계 기운)");
  if (hwagae) hits.push("화개 (고독·몰입·예술·연구 기운)");
  if (gongmang) hits.push("공망 (기운이 비어 집중이 흩어지기 쉬움)");

  return { cheoneulgwiin, yeongma, dohwa, hwagae, gongmang, hits };
}

// ──────────────────────────────────────────────────────────────
// 카테고리별 점수 (0~100) — 매핑 규칙을 코드에 명시
// ──────────────────────────────────────────────────────────────

function clampScore(x: number): number {
  return Math.max(0, Math.min(100, Math.round(x)));
}

interface CategoryInputs {
  group: TenGodGroup;
  elementScore: number; // -100..100
  relations: BranchRelationHit[];
  energy: number; // 0..100
  sinsal: FortuneEvidence["sinsal"];
}

function computeCategories(inp: CategoryInputs): FortuneCategoryScores {
  const { group, elementScore: es, relations, energy, sinsal } = inp;

  const energyC = (energy - 50) / 50; // -1..1
  const totalWeight = relations.reduce((a, r) => a + r.weight, 0) || 1;
  const relFactor = relations.reduce((a, r) => a + r.direction * r.weight, 0) / totalWeight; // -1..1

  const countKind = (kind: BranchRelationKind) => relations.filter((r) => r.relations.includes(kind)).length;
  const ilji = relations.find((r) => r.position === "일지");
  const iljiChung = ilji?.relations.includes("충") ?? false;
  const iljiHap = ilji ? ["육합", "삼합", "방합"].some((k) => ilji.relations.includes(k as BranchRelationKind)) : false;
  const hapCount = relations.filter((r) => r.relations.some((k) => k === "육합" || k === "삼합" || k === "방합")).length;
  const chungCount = countKind("충");
  const hyeongCount = countKind("형");
  const wonjinCount = countKind("원진");
  const anyHap = hapCount > 0;

  // 재물 = 재성 축 + 오행조력 (식상생재는 가점, 비겁은 재물 분탈로 감점)
  const tenGodMoney = { 재성: 16, 식상: 8, 관성: 2, 인성: -4, 비겁: -10 }[group];
  const money = clampScore(50 + tenGodMoney + es * 0.18 + relFactor * 8 + energyC * 6);

  // 애정 = 도화·합 중심 (일지 합/충에 민감, 배우자성=재성·관성 가점)
  const tenGodLove = { 재성: 6, 관성: 6, 식상: 3, 인성: 0, 비겁: -2 }[group];
  const love = clampScore(
    50 +
      (sinsal.dohwa ? 14 : 0) +
      (iljiHap ? 12 : anyHap ? 6 : 0) +
      (iljiChung ? -12 : 0) +
      (wonjinCount > 0 ? -6 : 0) +
      tenGodLove +
      es * 0.06,
  );

  // 직장·학업 = 관성·인성 중심 (에너지·귀인 가점, 공망 감점)
  const tenGodCareer = { 관성: 16, 인성: 13, 식상: 5, 재성: 4, 비겁: -4 }[group];
  const career = clampScore(
    50 + tenGodCareer + energyC * 10 + relFactor * 8 + (sinsal.cheoneulgwiin ? 8 : 0) + (sinsal.gongmang ? -6 : 0),
  );

  // 건강 = 오행조력 + 12운성 에너지 (충·형·공망은 피로·사고 신호로 감점)
  const health = clampScore(
    50 +
      energyC * 16 +
      es * 0.18 +
      (chungCount > 0 ? -8 * Math.min(chungCount, 2) : 0) +
      (hyeongCount > 0 ? -5 : 0) +
      (sinsal.gongmang ? -5 : 0),
  );

  // 대인관계 = 합·충 + 비겁 + 귀인·도화
  const tenGodRel = { 비겁: 6, 식상: 5, 인성: 2, 관성: 0, 재성: 0 }[group];
  const relationship = clampScore(
    50 +
      (hapCount > 0 ? 10 * Math.min(hapCount, 2) : 0) +
      (chungCount > 0 ? -10 * Math.min(chungCount, 2) : 0) +
      (wonjinCount > 0 ? -8 : 0) +
      (hyeongCount > 0 ? -5 : 0) +
      tenGodRel +
      (sinsal.cheoneulgwiin ? 8 : 0) +
      (sinsal.dohwa ? 5 : 0),
  );

  // 총운 = 다섯 영역 평균과 핵심 신호(오행·에너지·지지관계)의 블렌드
  const avg5 = (money + love + career + health + relationship) / 5;
  const core = 50 + es * 0.3 + energyC * 14 + relFactor * 10;
  const overall = clampScore(
    0.55 * avg5 + 0.45 * core + (sinsal.cheoneulgwiin ? 4 : 0) + (sinsal.gongmang ? -4 : 0),
  );

  return { overall, money, love, career, health, relationship };
}

// ──────────────────────────────────────────────────────────────
// 행운 아이템
// ──────────────────────────────────────────────────────────────

const ELEMENT_ITEMS: Record<string, { colors: string[]; direction: string; numbers: number[] }> = {
  목: { colors: ["초록", "청록"], direction: "동쪽", numbers: [3, 8] },
  화: { colors: ["빨강", "분홍"], direction: "남쪽", numbers: [2, 7] },
  토: { colors: ["노랑", "베이지"], direction: "중앙", numbers: [5, 10] },
  금: { colors: ["흰색", "은색"], direction: "서쪽", numbers: [4, 9] },
  수: { colors: ["검정", "남색"], direction: "북쪽", numbers: [1, 6] },
};

const LIUHE_PARTNER: Record<string, string> = {
  자: "축",
  축: "자",
  인: "해",
  해: "인",
  묘: "술",
  술: "묘",
  진: "유",
  유: "진",
  사: "신",
  신: "사",
  오: "미",
  미: "오",
};

const ZHI_HOUR_RANGE: Record<string, string> = {
  자: "23:00–01:00",
  축: "01:00–03:00",
  인: "03:00–05:00",
  묘: "05:00–07:00",
  진: "07:00–09:00",
  사: "09:00–11:00",
  오: "11:00–13:00",
  미: "13:00–15:00",
  신: "15:00–17:00",
  유: "17:00–19:00",
  술: "19:00–21:00",
  해: "21:00–23:00",
};

function computeLuckyItems(luckyElement: string, todayZhi: string): FortuneEvidence["luckyItems"] {
  const items = ELEMENT_ITEMS[luckyElement] ?? ELEMENT_ITEMS["토"];
  const partner = LIUHE_PARTNER[todayZhi] ?? todayZhi;
  return {
    element: luckyElement,
    colors: items.colors,
    direction: items.direction,
    numbers: items.numbers,
    timeSlot: { zhi: partner, range: ZHI_HOUR_RANGE[partner] ?? "" },
  };
}

// ──────────────────────────────────────────────────────────────
// 최상위: 오늘의 운세 근거 데이터 산출
// ──────────────────────────────────────────────────────────────

export function computeFortuneEvidence(birthInfo: BirthInfo, now: Date = new Date()): FortuneEvidence {
  const chart = computeSajuChart(birthInfo);
  const kst = kstDateOf(now);
  const gz = ganzhiForKstDate(kst);

  const dayGan = gz.day[0];
  const dayZhi = gz.day[1];
  const dayMaster = chart.dayMasterGan;

  // 원국 지지 (자리별) — 시지는 출생 시간을 알 때만
  const mineBranches: PositionedBranch[] = [
    { position: "연지", branch: chart.year.zhi },
    { position: "월지", branch: chart.month.zhi },
    { position: "일지", branch: chart.day.zhi },
    ...(chart.hour ? [{ position: "시지", branch: chart.hour.zhi }] : []),
  ];

  // 십성
  const tenGodName = tenGodOf(dayMaster, dayGan);
  const group = tenGodGroupOf(tenGodName);

  // 지지 관계
  const branchRelations = computeBranchRelations(mineBranches, dayZhi);

  // 오행 조력
  const yongshin = chart.yongshin?.supportive ?? [];
  const gishin = chart.yongshin?.unfavorable ?? [];
  const elementSupport = computeElementSupport(dayGan, dayZhi, yongshin, gishin);

  // 12운성
  const stage = twelveStageOf(dayMaster, dayZhi);
  const energyLevel = STAGE_ENERGY[stage] ?? 50;
  const twelveStage = {
    stage,
    energyLevel,
    detail: `오늘 지지 ${dayZhi}에서 일간 ${dayMaster}의 12운성은 '${stage}' (에너지 ${energyLevel}/100)`,
  };

  // 신살
  const gongmangZhis = gongmangOf(dayMaster, chart.day.zhi);
  const sinsal = computeSinsal(dayMaster, dayZhi, [chart.day.zhi, chart.year.zhi], gongmangZhis);

  // 카테고리 점수
  const categories = computeCategories({ group, elementScore: elementSupport.score, relations: branchRelations, energy: energyLevel, sinsal });

  // 행운 아이템 (길한 오행 = 용신 후보 1순위, 없으면 일간 오행)
  const luckyElement = yongshin[0] ?? elementKoOfGan(dayMaster);
  const luckyItems = computeLuckyItems(luckyElement, dayZhi);

  return {
    date: kst.iso,
    weekday: kst.weekday,
    ganzhi: { day: gz.day, dayGan, dayZhi, month: gz.month, year: gz.year },
    natal: {
      dayMaster,
      dayMasterElement: elementKoOfGan(dayMaster),
      pillars: {
        year: chart.year.ganZhi,
        month: chart.month.ganZhi,
        day: chart.day.ganZhi,
        hour: chart.hour?.ganZhi ?? null,
      },
      strength: chart.strength?.label ?? "중화",
      fiveElements: chart.fiveElements as FiveElementBalance,
      yongshin,
      gishin,
      hasHour: chart.hour !== null,
    },
    tenGod: { name: tenGodName, group, axis: TEN_GOD_AXIS[group] },
    branchRelations,
    elementSupport,
    twelveStage,
    sinsal,
    categories,
    luckyItems,
  };
}
