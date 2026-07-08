import type {
  EventActivation,
  EventForecast,
  EventScenario,
  EventScores,
  Gender,
  LifeDomain,
  LuckCycles,
  SajuChart,
} from "../types/index.js";

/**
 * 사건화 엔진 (무 API·결정론).
 *
 * 목적(감사 피드백):
 *   기존 계산(원국 십성/오행/충합형파해 + 대운·세운)은 "성향"까지는 잘 번역하지만,
 *   "직업/돈/연애/건강/가족/이사/창업 같은 현실 분야에서 어떤 사건이 지금 움직이는가"를
 *   규칙으로 연결하지 못하고 LLM에 통째로 맡기고 있었다. 이 모듈은 그 연결을 규칙화한다.
 *
 * 원칙(CLAUDE.md):
 *   - 계산은 결정론, 표면은 쉬운 말, 절대적 길흉/공포/단정 금지.
 *   - "이 사건이 일어난다"가 아니라 "이 분야가 지금 움직이기 쉬운 흐름 + 조심 신호"까지만.
 *   - 점수화(activation/benefit/risk)는 다음 단계에서 확장한다. 여기선 활성도(high/mid/low)까지.
 *   - saju.ts를 import하지 않는다(무거운 lunar-javascript가 서버 번들에 딸려오는 것 방지).
 *     필요한 작은 상수/판정은 이 파일에 인라인한다. (lifestyleGuide.ts와 같은 원칙)
 */

// ── 인라인 상수 (saju.ts와 동일, import 금지 원칙) ──────────
type Element = "wood" | "fire" | "earth" | "metal" | "water";

const GAN_WUXING: Record<string, Element> = {
  갑: "wood", 을: "wood",
  병: "fire", 정: "fire",
  무: "earth", 기: "earth",
  경: "metal", 신: "metal",
  임: "water", 계: "water",
};
const ZHI_WUXING: Record<string, Element> = {
  자: "water", 축: "earth", 인: "wood", 묘: "wood", 진: "earth", 사: "fire",
  오: "fire", 미: "earth", 신: "metal", 유: "metal", 술: "earth", 해: "water",
};
/** 지지 지장간 정기(마지막 원소) — 세운/대운 지지의 십성 판정용 */
const ZHI_MAIN_STEM: Record<string, string> = {
  자: "계", 축: "기", 인: "갑", 묘: "을", 진: "무", 사: "병",
  오: "정", 미: "기", 신: "경", 유: "신", 술: "무", 해: "임",
};
const YANG_GAN = new Set(["갑", "병", "무", "경", "임"]);

const GENERATES: Record<Element, Element> = {
  wood: "fire", fire: "earth", earth: "metal", metal: "water", water: "wood",
};
const OVERCOMES: Record<Element, Element> = {
  wood: "earth", earth: "water", water: "fire", fire: "metal", metal: "wood",
};

/** 지지 정기 천간 (외부 재사용: 과거 검증에서 세운 지지 십성 판정) */
export const ZHI_MAIN_STEM_TABLE: Record<string, string> = ZHI_MAIN_STEM;

/** 일간과 대상 천간의 십성 (saju.ts tenGodOf와 동일 규칙, 인라인) */
export function tenGodOf(dayGan: string, targetGan: string): string {
  const dayEl = GAN_WUXING[dayGan];
  const targetEl = GAN_WUXING[targetGan];
  if (!dayEl || !targetEl) return "?";
  const samePolarity = YANG_GAN.has(dayGan) === YANG_GAN.has(targetGan);
  if (targetEl === dayEl) return samePolarity ? "비견" : "겁재";
  if (GENERATES[targetEl] === dayEl) return samePolarity ? "편인" : "정인";
  if (GENERATES[dayEl] === targetEl) return samePolarity ? "식신" : "상관";
  if (OVERCOMES[dayEl] === targetEl) return samePolarity ? "편재" : "정재";
  return samePolarity ? "편관" : "정관";
}

// ── 십성 그룹 ──────────
export type TenGodGroup = "비겁" | "식상" | "재성" | "관성" | "인성";
const TEN_GOD_GROUP: Record<string, TenGodGroup> = {
  비견: "비겁", 겁재: "비겁",
  식신: "식상", 상관: "식상",
  편재: "재성", 정재: "재성",
  편관: "관성", 정관: "관성", 칠살: "관성",
  편인: "인성", 정인: "인성", 인수: "인성",
};

export function groupOf(tenGod: string): TenGodGroup | null {
  for (const name of Object.keys(TEN_GOD_GROUP)) {
    if (tenGod.includes(name)) return TEN_GOD_GROUP[name];
  }
  return null;
}

// ── 궁위(위치) 라벨 ──────────
const POSITION_LABELS = ["연간", "연지", "월간", "월지", "일간", "일지", "시간", "시지"] as const;
export type PositionLabel = (typeof POSITION_LABELS)[number];

/** 궁위가 상징하는 현실 대상 (충/합이 어디를 흔드는지 해석용) */
export const POSITION_MEANING: Record<PositionLabel, string> = {
  연간: "사회·바깥 활동, 윗세대",
  연지: "사회 기반·초년 환경",
  월간: "직업·사회활동",
  월지: "직업·부모·형제의 자리",
  일간: "나 자신",
  일지: "배우자·가장 가까운 관계의 자리",
  시간: "아랫사람·미래 계획",
  시지: "자녀·말년·마무리의 자리",
};

// ── 분야 라벨 ──────────
export const DOMAIN_LABEL: Record<LifeDomain, string> = {
  career: "직업·일",
  money: "돈·재물",
  love: "연애·관계",
  health: "건강·컨디션",
  family: "가족",
  move: "이사·이동",
  startup: "창업·독립",
};

const DOMAIN_ORDER: LifeDomain[] = ["career", "money", "love", "health", "family", "move", "startup"];

// ── 원국 십성 파싱 ──────────
interface ParsedTenGod {
  position: PositionLabel | null;
  group: TenGodGroup;
  raw: string;
}

/** chart.tenGods("연간 경: 편재") / branchTenGods("연지 축(정기 기): 상관") 문자열 파싱 */
function parseNatalTenGods(chart: SajuChart): ParsedTenGod[] {
  const out: ParsedTenGod[] = [];
  const all = [...(chart.tenGods ?? []), ...(chart.branchTenGods ?? [])];
  for (const raw of all) {
    const position = POSITION_LABELS.find((p) => raw.startsWith(p)) ?? null;
    const group = groupOf(raw);
    if (group) out.push({ position, group, raw });
  }
  return out;
}

/** 십성 그룹별 개수 */
function groupCounts(parsed: ParsedTenGod[]): Record<TenGodGroup, number> {
  const counts: Record<TenGodGroup, number> = { 비겁: 0, 식상: 0, 재성: 0, 관성: 0, 인성: 0 };
  for (const p of parsed) counts[p.group] += 1;
  return counts;
}

// ── 상호작용(충합형파해) 파싱 ──────────
export type InteractionKind = "충" | "형" | "파" | "해" | "합" | "삼합" | "반합" | "방합" | "자형";

export interface ParsedInteraction {
  kind: InteractionKind;
  positions: PositionLabel[];
  raw: string;
}

export function parseInteraction(raw: string): ParsedInteraction | null {
  const positions = POSITION_LABELS.filter((p) => raw.includes(p));
  let kind: InteractionKind | null = null;
  if (raw.includes("삼합")) kind = "삼합";
  else if (raw.includes("반합")) kind = "반합";
  else if (raw.includes("방합")) kind = "방합";
  else if (raw.includes("자형")) kind = "자형";
  else if (raw.includes("충")) kind = "충";
  else if (raw.includes("형")) kind = "형";
  else if (raw.includes("파")) kind = "파";
  else if (raw.includes("해")) kind = "해";
  else if (raw.includes("합")) kind = "합";
  if (!kind) return null;
  return { kind, positions, raw };
}

/** 충합형파해의 성격을 쉬운 말로 */
export const KIND_NUANCE: Record<InteractionKind, string> = {
  충: "부딪히고 자리가 바뀌는 변동",
  형: "속으로 쌓이는 압박·마찰",
  파: "계획이 어긋나 수정이 필요한 흐름",
  해: "은근한 방해·오해가 끼는 흐름",
  합: "끌리고 묶이는 결합·시작",
  삼합: "한 방향으로 크게 뭉치는 흐름",
  반합: "한 방향으로 모이려는 흐름",
  방합: "같은 계절 기운이 뭉치는 흐름",
  자형: "스스로 반복해 자초하는 긴장",
};

// ── 세운/대운 간지의 십성 → 활성 분야 ──────────
interface LuckSignal {
  scope: "대운" | "세운" | "월운";
  ganZhi: string;
  stemGroup: TenGodGroup | null;
  branchGroup: TenGodGroup | null;
  stemEl: Element;
  branchEl: Element;
}

function luckSignalOf(scope: LuckSignal["scope"], ganZhi: string | null | undefined, dayGan: string): LuckSignal | null {
  if (!ganZhi || ganZhi.length < 2) return null;
  const gan = ganZhi[0];
  const zhi = ganZhi[1];
  const stemGroup = groupOf(tenGodOf(dayGan, gan));
  const mainStem = ZHI_MAIN_STEM[zhi];
  const branchGroup = mainStem ? groupOf(tenGodOf(dayGan, mainStem)) : null;
  return { scope, ganZhi, stemGroup, branchGroup, stemEl: GAN_WUXING[gan], branchEl: ZHI_WUXING[zhi] };
}

// ── 십성 그룹 → 분야 매핑 ──────────
/** 십성 그룹이 어떤 분야에 사건으로 나타나기 쉬운지 (성별 의존은 아래에서 별도 처리) */
export const GROUP_DOMAINS: Record<TenGodGroup, LifeDomain[]> = {
  비겁: ["money", "startup", "family"],
  식상: ["startup", "career", "love"],
  재성: ["money", "love", "career"],
  관성: ["career", "love"],
  인성: ["move", "career", "family"],
};

/** 원국 십성 우세 그룹이 각 분야에 남기는 "나타나기 쉬운 사건" 문구 */
function natalPatternsFor(domain: LifeDomain, counts: Record<TenGodGroup, number>, gender?: Gender): string[] {
  const out: string[] = [];
  const strong = (g: TenGodGroup) => counts[g] >= 2;
  const some = (g: TenGodGroup) => counts[g] >= 1;

  switch (domain) {
    case "career":
      if (strong("관성")) out.push("맡은 역할·직책이 커지거나 책임이 몰리는 일이 반복되기 쉽습니다.");
      if (some("식상")) out.push("하고 싶은 걸 밖으로 풀어내다 이직·독립 욕구가 올라오기 쉽습니다.");
      if (strong("인성")) out.push("자격·문서·전문성으로 자리를 잡는 흐름이 잘 맞습니다.");
      if (out.length === 0) out.push("한 분야를 꾸준히 쌓아 신뢰로 자리를 만드는 편이 잘 맞습니다.");
      break;
    case "money":
      if (strong("재성")) out.push("돈·성과를 직접 만들고 굴리는 기회가 자주 생깁니다.");
      if (strong("비겁")) out.push("경쟁·동업·나눠 쓰는 상황에서 재물이 새기 쉬워 관리가 중요합니다.");
      if (some("식상")) out.push("만든 것·표현한 것이 수입으로 이어지는 구조입니다.");
      if (out.length === 0) out.push("한 번에 크게 벌기보다 꾸준한 관리로 모으는 편이 안정적입니다.");
      break;
    case "love":
      if (gender === "male" && some("재성")) out.push("인연·이성 관계가 현실 조건·타이밍과 함께 움직이기 쉽습니다.");
      if (gender === "female" && some("관성")) out.push("관계에서 상대의 역할·책임감이 크게 느껴지기 쉽습니다.");
      if (strong("식상")) out.push("표현이 앞서 감정이 빨리 커지고 빨리 식기도 쉽습니다.");
      if (out.length === 0) out.push("관계는 감정보다 생활 리듬이 맞을 때 오래 갑니다.");
      break;
    case "health":
      out.push("컨디션은 무리·과로가 쌓일 때 몸의 약한 부위부터 신호가 옵니다.");
      break;
    case "family":
      if (some("인성")) out.push("윗세대·집안 문제(문서·부양·정리)가 나에게 흘러들기 쉽습니다.");
      if (strong("비겁")) out.push("형제·가까운 사람과의 역할 분담·금전 문제가 반복되기 쉽습니다.");
      if (out.length === 0) out.push("가족 안에서 조율자 역할을 맡기 쉬운 편입니다.");
      break;
    case "move":
      if (some("인성")) out.push("문서·계약·부동산과 얽힌 이동이 생기기 쉽습니다.");
      out.push("환경·거주지가 한 번씩 크게 바뀌는 흐름이 올 수 있습니다.");
      break;
    case "startup":
      if (strong("식상")) out.push("직접 만들고 벌이는 일에서 에너지가 크게 나옵니다.");
      if (strong("비겁")) out.push("동업·독립을 시도하기 쉬우나 지분·역할을 분명히 해야 합니다.");
      if (some("재성")) out.push("아이템을 현실 수익으로 연결하는 감각이 있습니다.");
      if (out.length === 0) out.push("크게 벌이기 전에 작게 검증하는 방식이 잘 맞습니다.");
      break;
  }
  return [...new Set(out)];
}

/** 분야별 조심 신호 (원국 편중 + 오행 고립 기반) */
function cautionsFor(domain: LifeDomain, chart: SajuChart, counts: Record<TenGodGroup, number>): string[] {
  const out: string[] = [];
  const five = chart.fiveElements;
  const dayEl = GAN_WUXING[chart.dayMasterGan];
  const strong = chart.strength?.label;

  switch (domain) {
    case "career":
      if (counts.관성 >= 3) out.push("책임이 과하게 몰릴 때 번아웃이 오기 쉬우니 역할을 나누세요.");
      if (counts.관성 === 0) out.push("틀·규칙이 약해 조직 안에서 답답함을 느끼기 쉽습니다.");
      break;
    case "money":
      if (counts.비겁 >= 3) out.push("보증·동업·빌려주기에서 손실이 나기 쉬우니 선을 분명히 하세요.");
      if (counts.재성 === 0) out.push("돈을 직접 굴리기보다 안정적 관리가 더 맞습니다.");
      break;
    case "love":
      if (counts.식상 >= 3) out.push("말이 앞서 감정 소모가 커질 수 있으니 속도를 조절하세요.");
      break;
    case "health":
      if (dayEl && five[dayEl] <= 1) out.push("일간 기운이 약해 무리하면 회복이 더딜 수 있습니다.");
      if (strong === "신강") out.push("힘이 강해 과로를 밀어붙이다 한 번에 무너지기 쉽습니다.");
      break;
    case "family":
      if (counts.인성 >= 3) out.push("집안 일을 혼자 떠안다 지치기 쉬우니 분담이 필요합니다.");
      break;
    case "move":
      out.push("급한 이동·계약은 서두르지 말고 시기와 조건을 함께 확인하세요.");
      break;
    case "startup":
      if (strong === "신약") out.push("혼자 밀기보다 협력·환경을 먼저 갖추는 편이 안전합니다.");
      if (counts.재성 === 0) out.push("수익 구조를 먼저 검증하지 않으면 확장에서 흔들리기 쉽습니다.");
      break;
  }
  return out;
}

function clamp100(n: number): number {
  return Math.max(0, Math.min(100, Math.round(n)));
}

/** 합 계열(결합·기회 성향) / 충형파해(변동·부담 성향) 구분 */
export const BENEFIT_KINDS = new Set<InteractionKind>(["합", "삼합", "반합", "방합"]);
export const RISK_KINDS = new Set<InteractionKind>(["충", "형", "파", "해", "자형"]);

/** 상호작용 + 세운/대운 신호로 분야별 활성도·이득·위험 점수와 타이밍 신호를 만든다 */
function activationFor(
  domain: LifeDomain,
  interactions: ParsedInteraction[],
  luckSignals: LuckSignal[],
  natalByPosition: Map<PositionLabel, TenGodGroup[]>,
  yong: Set<Element>,
  avoid: Set<Element>,
  counts: Record<TenGodGroup, number>,
): { activation: EventActivation; scores: EventScores; note: string; timing: string[]; evidence: string[] } {
  const timing: string[] = [];
  const evidence: string[] = [];
  let score = 0;
  let benefitRaw = 0;
  let riskRaw = 0;

  // 1) 세운/대운/월운 간지의 십성이 이 분야를 직접 활성화 + 그 간지 오행의 용신/기신 방향으로 이득/위험 판정
  for (const sig of luckSignals) {
    const groups = [sig.stemGroup, sig.branchGroup].filter(Boolean) as TenGodGroup[];
    if (groups.some((g) => GROUP_DOMAINS[g].includes(domain))) {
      const weight = sig.scope === "세운" ? 2 : sig.scope === "대운" ? 1.5 : 1;
      score += weight;
      timing.push(`${sig.scope}(${sig.ganZhi})에 ${domainVerb(domain)} 기운이 들어오는 흐름입니다.`);
      evidence.push(`${sig.scope} ${sig.ganZhi} → ${groups.join("·")} 계열, ${DOMAIN_LABEL[domain]} 연결`);
      // 그 운 간지의 오행이 보완 기운(용신)이면 이득 방향, 부담 기운(기신)이면 위험 방향
      for (const el of [sig.stemEl, sig.branchEl]) {
        if (yong.has(el)) benefitRaw += weight * 0.6;
        else if (avoid.has(el)) riskRaw += weight * 0.6;
      }
    }
  }

  // 2) 원국·운 상호작용(충합형파해)이 이 분야와 연결된 궁위를 흔드는지 + 합=이득/충형파해=위험 성향
  for (const it of interactions) {
    const domainsHit = new Set<LifeDomain>();
    for (const pos of it.positions) {
      for (const g of natalByPosition.get(pos) ?? []) {
        for (const d of GROUP_DOMAINS[g]) domainsHit.add(d);
      }
      // 궁위 자체가 특정 분야를 상징하는 경우도 반영
      for (const d of positionDomains(pos)) domainsHit.add(d);
    }
    if (domainsHit.has(domain)) {
      const weight = it.kind === "충" || it.kind === "삼합" ? 1.5 : 1;
      score += weight;
      if (BENEFIT_KINDS.has(it.kind)) benefitRaw += weight;
      else if (RISK_KINDS.has(it.kind)) riskRaw += weight;
      timing.push(`${it.raw.replace(/[()]/g, " ").trim()} — ${KIND_NUANCE[it.kind]}이 이 분야에 닿습니다.`);
      const palace = it.positions.map((p) => POSITION_MEANING[p]).filter(Boolean).join(", ");
      evidence.push(`상호작용 ${it.raw} → ${DOMAIN_LABEL[domain]}${palace ? ` (${palace})` : ""}`);
    }
  }

  // 3) 원국 역량: 이 분야를 담당하는 십성이 넉넉하면 잘 다루는 분야(이득 쪽 base), 비어 있으면 취약(위험 쪽 base)
  const domainGroups = (Object.keys(GROUP_DOMAINS) as TenGodGroup[]).filter((g) => GROUP_DOMAINS[g].includes(domain));
  const domainCap = domainGroups.reduce((s, g) => s + counts[g], 0);
  if (domainCap >= 3) benefitRaw += 0.6;
  else if (domainCap === 0) riskRaw += 0.5;

  const activation: EventActivation = score >= 3 ? "high" : score >= 1.5 ? "mid" : "low";
  const activationScore = clamp100(score * 22);
  const benefit = clamp100(benefitRaw * 22 + (activation !== "low" ? 8 : 0));
  const risk = clamp100(riskRaw * 22);

  let balance: EventScores["balance"];
  if (activation === "low") balance = "calm";
  else if (benefit - risk >= 18) balance = "opportunity";
  else if (risk - benefit >= 18) balance = "caution";
  else balance = "mixed";

  const note =
    activation === "low"
      ? "지금은 크게 흔들리지 않는 평이한 흐름입니다."
      : balance === "opportunity"
        ? "지금 이 분야는 잘 살리면 기회가 되는 흐름입니다."
        : balance === "caution"
          ? "지금 이 분야는 부담·변동이 커서 점검이 필요한 흐름입니다."
          : "지금 이 분야는 기회와 부담이 함께 있어, 어떻게 다루느냐가 중요한 흐름입니다.";

  return {
    activation,
    scores: { activation: activationScore, benefit, risk, balance },
    note,
    timing: [...new Set(timing)].slice(0, 4),
    evidence: [...new Set(evidence)].slice(0, 5),
  };
}

/** 궁위가 직접 상징하는 분야 (충/합이 그 자리를 흔들 때 사건 연결) */
export function positionDomains(pos: PositionLabel): LifeDomain[] {
  switch (pos) {
    case "월간":
    case "월지":
      return ["career", "family"];
    case "일지":
      return ["love"];
    case "연간":
    case "연지":
      return ["career", "move"];
    case "시간":
    case "시지":
      return ["family"];
    default:
      return [];
  }
}

function domainVerb(domain: LifeDomain): string {
  switch (domain) {
    case "career": return "직업·역할이 움직이는";
    case "money": return "돈·성과가 움직이는";
    case "love": return "관계·인연이 움직이는";
    case "health": return "몸·컨디션을 챙겨야 하는";
    case "family": return "집안·가족이 움직이는";
    case "move": return "이동·환경이 바뀌는";
    case "startup": return "새로 벌이는";
  }
}

export function buildEventForecast(chart?: SajuChart, luck?: LuckCycles, gender?: Gender): EventForecast | null {
  if (!chart) return null;

  const dayGan = chart.dayMasterGan;
  const parsed = parseNatalTenGods(chart);
  const counts = groupCounts(parsed);

  // 궁위 → 십성 그룹 맵 (상호작용이 흔드는 자리의 십성 판정용)
  const natalByPosition = new Map<PositionLabel, TenGodGroup[]>();
  for (const p of parsed) {
    if (!p.position) continue;
    const list = natalByPosition.get(p.position) ?? [];
    list.push(p.group);
    natalByPosition.set(p.position, list);
  }

  const interactions = (chart.interactions ?? [])
    .map(parseInteraction)
    .filter((x): x is ParsedInteraction => x !== null);

  // 용신(보완하면 좋은 기운) / 기신(과하면 부담) 오행 집합 — 이득/위험 방향 판정용
  const koToEl: Record<string, Element> = { 목: "wood", 화: "fire", 토: "earth", 금: "metal", 수: "water" };
  const toElSet = (arr?: string[]) =>
    new Set<Element>((arr ?? []).map((k) => koToEl[k]).filter((x): x is Element => Boolean(x)));
  const yong = toElSet(chart.yongshin?.supportive ?? chart.yongshin?.yongshin);
  const avoid = toElSet(chart.yongshin?.unfavorable);

  // 대운·세운·월운 신호 (luck 없으면 원국만으로)
  const luckSignals: LuckSignal[] = [];
  if (luck) {
    const dae = luckSignalOf("대운", luck.currentDaYun, dayGan);
    if (dae) luckSignals.push(dae);
    const se = luckSignalOf("세운", luck.yearGanZhi, dayGan);
    if (se) luckSignals.push(se);
    const wol = luckSignalOf("월운", luck.monthGanZhi, dayGan);
    if (wol) luckSignals.push(wol);
  }
  // 운이 원국과 새로 맺는 상호작용도 타이밍 근거에 포함
  const luckInteractions = (luck?.luckInteractions ?? [])
    .map(parseInteraction)
    .filter((x): x is ParsedInteraction => x !== null);
  const allTimingInteractions = [...interactions, ...luckInteractions];

  const domains: EventScenario[] = DOMAIN_ORDER.map((domain) => {
    const { activation, scores, note, timing, evidence } = activationFor(
      domain,
      allTimingInteractions,
      luckSignals,
      natalByPosition,
      yong,
      avoid,
      counts,
    );
    const patterns = natalPatternsFor(domain, counts, gender);
    // activation이 있는 분야는 4개 고정 문장에서 그치지 않고, 이 사람의 실제 원국 패턴 한 줄을
    // 이어 붙여 매번 다른 근거가 보이게 한다 (patterns는 이미 십성 원문 없이 순화된 문장).
    const activationNote = activation !== "low" && patterns.length > 0 ? `${note} ${patterns[0]}` : note;
    return {
      domain,
      label: DOMAIN_LABEL[domain],
      activation,
      scores,
      activationNote,
      patterns,
      timingSignals: timing,
      cautions: cautionsFor(domain, chart, counts),
      evidence,
    };
  });

  const activationRank: Record<EventActivation, number> = { high: 2, mid: 1, low: 0 };
  const activeDomains = domains
    .filter((d) => d.activation !== "low")
    .sort((a, b) => activationRank[b.activation] - activationRank[a.activation])
    .map((d) => d.domain);

  const oppLabels = domains.filter((d) => d.scores.balance === "opportunity").map((d) => d.label);
  const cauLabels = domains.filter((d) => d.scores.balance === "caution").map((d) => d.label);
  let headline: string;
  if (oppLabels.length > 0 && cauLabels.length > 0) {
    headline = `지금은 ${oppLabels.slice(0, 2).join("·")} 쪽은 살리기 좋고, ${cauLabels.slice(0, 2).join("·")} 쪽은 점검이 필요한 시기입니다.`;
  } else if (oppLabels.length > 0) {
    headline = `지금은 ${oppLabels.slice(0, 2).join("·")} 쪽을 잘 살리면 기회가 되는 시기입니다.`;
  } else if (cauLabels.length > 0) {
    headline = `지금은 ${cauLabels.slice(0, 2).join("·")} 쪽에서 부담·변동을 점검해야 하는 시기입니다.`;
  } else if (activeDomains.length > 0) {
    headline = `지금은 ${activeDomains.slice(0, 2).map((k) => DOMAIN_LABEL[k]).join("·")} 쪽이 움직이지만, 기회와 부담이 섞여 있어 다루기 나름인 시기입니다.`;
  } else {
    headline = "지금은 어느 한 분야가 크게 흔들리기보다, 전반적으로 평이한 시기입니다.";
  }

  return { domains, activeDomains, headline };
}
