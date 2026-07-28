import { lookupZiweiCombo } from "../data/ziweiCombos.js";
import type { ZiweiChart, ZiweiLuck, ZiweiLuckScope, ZiweiPalace } from "./ziwei.js";

/**
 * 자미두수 해석 레이어 (Phase 1).
 *
 * 목적: 원식(12궁×별)을 앱의 분야(직업/재물/애정/건강/멘탈/가족)별 '좋음/보통/주의' 경향으로
 * 정규화한다. 이 판정은 다음 단계에서 사주 분야 판정과 교차검증하는 데 쓴다.
 *
 * 한계(반드시 지킬 것):
 *   - 별의 길흉은 유파·격국·조합에 따라 크게 갈린다. 여기 valence는 교차검증의 '방향'을 잡기 위한
 *     의도적으로 거친 근사다. 단정 근거가 아니라 경향 신호로만 쓰고, 표면 문장은 항상 '~한 편'으로.
 *   - 자미두수 용어(별 이름·궁 이름·사화)는 (근거)에만 남기고 사용자 표면 문장엔 노출하지 않는다.
 */

/** 앱 분야 → 자미두수 궁 (교차검증에 쓸 6개 축) */
const DOMAIN_PALACE: Record<string, { label: string; palace: string }> = {
  career: { label: "직업", palace: "관록" },
  money: { label: "재물", palace: "재백" },
  love: { label: "애정·관계", palace: "부처" },
  health: { label: "건강", palace: "질액" },
  mental: { label: "멘탈·감정", palace: "복덕" },
  family: { label: "가족", palace: "부모" },
};

/**
 * 주성·보좌성·살성의 거친 길흉값. +1 길, 0 중립/양면, -1 주의.
 * (조합·격국을 무시한 근사임을 전제로 함 — 교차검증 방향 판정용)
 */
const STAR_VALENCE: Record<string, number> = {
  // 14 주성
  자미: 1, 천부: 1, 천상: 1, 천동: 1, 태양: 1, 태음: 1, 천기: 1, 천량: 1, 무곡: 1,
  탐랑: 0, 염정: 0,
  거문: -1, 칠살: -1, 파군: -1,
  // 보좌 길성
  문창: 1, 문곡: 1, 좌보: 1, 우필: 1, 천괴: 1, 천월: 1, 록존: 1, 천마: 1,
  // 살성
  경양: -1, 타라: -1, 화성: -1, 영성: -1, 지공: -1, 지겁: -1, 천형: -1,
};

/** 사화(록·권·과·기) 값 */
const MUTAGEN_VALENCE: Record<string, number> = { 록: 1, 권: 1, 과: 1, 기: -1 };

/** 별을 쉬운 말로 (표면 금지, 근거·설명용) */
const STAR_GLOSS: Record<string, string> = {
  자미: "중심을 잡고 이끄는 기운", 천부: "쌓고 지키는 안정의 기운", 천상: "돕고 조율하는 기운",
  천동: "부드럽고 즐기는 기운", 태양: "드러나고 베푸는 기운", 태음: "안으로 살피고 모으는 기운",
  천기: "머리 굴리고 변화하는 기운", 천량: "돌보고 원칙 세우는 기운", 무곡: "실행하고 벌어들이는 기운",
  탐랑: "욕망·재주가 강한 양면의 기운", 염정: "복잡하고 강렬한 양면의 기운",
  거문: "말·시비가 따르기 쉬운 기운", 칠살: "치고 나가는 개척·변동의 기운", 파군: "부수고 새로 짓는 변동의 기운",
  문창: "글·공부의 기운", 문곡: "표현·재예의 기운", 좌보: "곁에서 돕는 기운", 우필: "곁에서 돕는 기운",
  천괴: "귀인의 도움", 천월: "귀인의 도움", 록존: "재물·안정의 기운", 천마: "움직임·이동의 기운",
  경양: "날카롭게 부딪히는 기운", 타라: "지체·엉킴의 기운", 화성: "급하게 타오르는 기운",
  영성: "속으로 타는 기운", 지공: "비고 흩어지는 기운", 지겁: "새어나가는 기운", 천형: "제약·긴장의 기운",
};

export type ZiweiTone = "좋음" | "보통" | "주의";

export interface ZiweiDomainVerdict {
  domain: string;
  label: string;
  /** 근거용 궁 이름 (표면 금지) */
  palace: string;
  tone: ZiweiTone;
  score: number;
  /** 그 궁의 주성 (근거용) */
  stars: string[];
  /** 쉬운 말 요지 */
  note: string;
  /** 전문가 근거용 상세 */
  evidence: string;
}

// 묘왕리함 밝기 → 세기 배율. 함(-3)이면 0(밝지 않아 힘을 못 씀), 평(0)이면 1, 묘(+3)이면 2.
function brightnessWeight(brightness: number): number {
  return Math.max(0, Math.min(2, 1 + brightness / 3));
}

/** 별 하나의 기여 = 기본 길흉 × 밝기 배율 (밝기가 별의 나머지 성질을 증폭/약화) */
function starContribution(name: string, brightness: number): number {
  const base = STAR_VALENCE[name];
  return base === undefined ? 0 : base * brightnessWeight(brightness);
}

function scorePalace(palace: ZiweiPalace): { score: number; stars: string[]; glosses: string[] } {
  let score = 0;
  const stars: string[] = [];
  const glosses: string[] = [];

  // 본궁 주성: 밝기 가중
  for (const s of palace.majorStars) {
    score += starContribution(s.name, s.brightness);
    if (s.name in STAR_VALENCE) {
      stars.push(s.name);
      if (STAR_GLOSS[s.name]) glosses.push(`${s.name}${brightnessTag(s.brightness)}(${STAR_GLOSS[s.name]})`);
    }
    if (s.mutagen && s.mutagen in MUTAGEN_VALENCE) score += MUTAGEN_VALENCE[s.mutagen];
  }
  // 동궁 주성 조합 gloss (Z-3): 두 주성이 함께 앉는 실존 조합이면 그 조합의 성격 근거를 덧붙인다.
  // 점수(score)는 건드리지 않고 근거 텍스트만 풍부하게 한다(기존 tone 스냅샷 불변).
  const majorNames = palace.majorStars.map((s) => s.name);
  if (majorNames.length === 2) {
    const combo = lookupZiweiCombo(majorNames);
    if (combo) glosses.push(`[동궁] ${combo.stars.join("·")}: ${combo.gloss}`);
  }
  // 보좌·살성(minor): 밝기 정보 없어 기본값의 0.7배
  for (const name of palace.minorStars) {
    if (name in STAR_VALENCE) {
      score += STAR_VALENCE[name] * 0.7;
      stars.push(name);
      if (STAR_GLOSS[name]) glosses.push(`${name}(${STAR_GLOSS[name]})`);
    }
  }
  // 삼방사정 방조: 대궁·삼합궁 주성을 절반 가중으로 참작 (빈 궁도 여기서 힘을 빌린다)
  for (const s of palace.sanfangStars) {
    score += starContribution(s.name, s.brightness) * 0.5;
    if (s.mutagen && s.mutagen in MUTAGEN_VALENCE) score += MUTAGEN_VALENCE[s.mutagen] * 0.5;
  }

  return { score, stars, glosses };
}

function brightnessTag(b: number): string {
  if (b >= 2) return "(밝음)";
  if (b <= -2) return "(어두움)";
  return "";
}

function toneOf(score: number): ZiweiTone {
  if (score >= 1.5) return "좋음";
  if (score <= -1.5) return "주의";
  return "보통";
}

const TONE_NOTE: Record<string, Record<ZiweiTone, string>> = {
  career: {
    좋음: "직업 자리는 힘이 실려, 자리를 잡고 넓히기 좋은 편입니다.",
    보통: "직업 자리는 크게 튀지 않아, 꾸준함으로 쌓는 편이 맞습니다.",
    주의: "직업 자리에 변동·마찰이 끼기 쉬워, 무리한 확장보다 점검이 필요한 편입니다.",
  },
  money: {
    좋음: "재물 자리는 들고 쌓는 힘이 있어, 굴리기 좋은 편입니다.",
    보통: "재물 자리는 무난해, 관리로 지키는 편이 맞습니다.",
    주의: "재물 자리에 새거나 엉키는 기운이 있어, 큰 지출·보증은 조심하는 편이 낫습니다.",
  },
  love: {
    좋음: "관계 자리는 안정과 인연의 힘이 있어, 맺고 이어가기 좋은 편입니다.",
    보통: "관계 자리는 담담해, 생활 리듬으로 맞춰가는 편이 맞습니다.",
    주의: "관계 자리에 흔들림·오해가 끼기 쉬워, 속도를 조절하는 편이 낫습니다.",
  },
  health: {
    좋음: "건강 자리는 무난한 편이라, 지금 리듬을 지키기 좋습니다.",
    보통: "건강 자리는 크게 걸리는 것 없이 평이한 편입니다.",
    주의: "건강 자리에 소모·긴장이 끼기 쉬워, 무리를 덜고 회복을 챙기는 편이 낫습니다.",
  },
  mental: {
    좋음: "마음 자리는 여유와 즐김의 힘이 있어, 안으로 안정된 편입니다.",
    보통: "마음 자리는 담담한 편이라, 생각을 정리하며 지내기 좋습니다.",
    주의: "마음 자리에 긴장·생각 과다가 끼기 쉬워, 내려놓는 연습이 필요한 편입니다.",
  },
  family: {
    좋음: "가족 자리는 든든한 편이라, 기대고 나누기 좋습니다.",
    보통: "가족 자리는 무난한 편입니다.",
    주의: "가족 자리에 부담·거리감이 끼기 쉬워, 역할과 선을 정리하는 편이 낫습니다.",
  },
};

// ── 운한(대한·유년) 해석 — 엔진 업그레이드 Z-2 (docs/engine-upgrade-2026-07.md) ──────────
// 원식 valence(위 STAR_VALENCE/scorePalace)를 그대로 재사용하는 '거친 근사'다. 새 근거 계산이
// 아니라, Z-1의 iztro 운한 데이터를 같은 방식으로 방향(좋음/보통/주의)만 잡는다.
// 판정 논리:
//   1) 운한 명궁이 앉는 본명 궁이 6개 도메인 궁 중 하나면 → 그 도메인이 "이 기간의 중심 무대"
//      + 그 본명 궁 자체 점수를 절반 가중으로 얹는다(scorePalace 재사용).
//   2) 운한 사화(록/권/과/기)가 붙는 별의 본명 소재궁이 도메인 궁이면 → 그 도메인에 사화값 가감
//      (록·권·과 = +, 기 = 주의).

/** 본명 궁 이름 → 앱 도메인 (DOMAIN_PALACE 역매핑) */
const PALACE_DOMAIN: Record<string, { domain: string; label: string }> = Object.fromEntries(
  Object.entries(DOMAIN_PALACE).map(([domain, { label, palace }]) => [palace, { domain, label }]),
);

const LUCK_TONE_WORD: Record<ZiweiTone, string> = {
  좋음: "힘이 실리는",
  보통: "담담하게 흘러가는",
  주의: "마찰·변동이 끼기 쉬운",
};

export interface ZiweiLuckVerdict {
  scope: "decade" | "year";
  scopeLabel: string;
  domain: string;
  label: string;
  tone: ZiweiTone;
  score: number;
  /** 이 기간 이 도메인이 '중심 무대'인지 (운한 명궁이 이 본명 궁에 앉음) */
  isStage: boolean;
  note: string;
  /** 전문가 근거 (표면 금지 용어 포함) */
  evidence: string;
}

function scopeVerdicts(chart: ZiweiChart, scope: ZiweiLuckScope, kind: "decade" | "year"): ZiweiLuckVerdict[] {
  const scopeLabel = kind === "decade" ? "이번 10년(대한)" : "올해(유년)";
  const byName = new Map(chart.palaces.map((p) => [p.name, p]));
  const acc = new Map<string, { score: number; stage: boolean; reasons: string[] }>();
  const bump = (palaceName: string | null, delta: number, stage: boolean, reason: string) => {
    if (!palaceName) return;
    const entry = PALACE_DOMAIN[palaceName];
    if (!entry) return;
    const cur = acc.get(entry.domain) ?? { score: 0, stage: false, reasons: [] };
    cur.score += delta;
    cur.stage = cur.stage || stage;
    cur.reasons.push(reason);
    acc.set(entry.domain, cur);
  };

  // 1) 운한 명궁이 앉는 본명 궁 = 이 기간의 중심 무대
  if (scope.palaceOfSoul) {
    const natal = byName.get(scope.palaceOfSoul.name);
    if (natal) {
      const { score } = scorePalace(natal);
      bump(scope.palaceOfSoul.name, score * 0.5, true, `운한 명궁이 본명 ${scope.palaceOfSoul.name}궁에 듦(무대) ${Math.round(score * 10) / 10 >= 0 ? "+" : ""}${Math.round(score * 5) / 10}`);
    }
  }
  // 2) 운한 사화 → 붙는 별의 본명 소재궁 도메인에 가감
  for (const m of scope.mutagens) {
    const delta = MUTAGEN_VALENCE[m.type] ?? 0;
    bump(m.natalPalace, delta, false, `${m.star} 화${m.type}${m.natalPalace ? ` (본명 ${m.natalPalace}궁)` : ""}`);
  }

  const verdicts: ZiweiLuckVerdict[] = [];
  for (const [domain, { score, stage, reasons }] of acc.entries()) {
    const { label } = DOMAIN_PALACE[domain];
    const tone = toneOf(score);
    const rounded = Math.round(score * 10) / 10;
    verdicts.push({
      scope: kind,
      scopeLabel,
      domain,
      label,
      tone,
      score: rounded,
      isStage: stage,
      note: `${scopeLabel}은 ${label} 자리가 ${stage ? "중심에 오며 " : ""}${LUCK_TONE_WORD[tone]} 편입니다.`,
      evidence: `${scopeLabel} ${DOMAIN_PALACE[domain].palace}궁 신호: ${reasons.join(" / ")} → ${tone}(${rounded})`,
    });
  }
  // 무대(명궁 소재) 도메인을 먼저, 그다음 점수 절대값 큰 순
  return verdicts.sort((a, b) => Number(b.isStage) - Number(a.isStage) || Math.abs(b.score) - Math.abs(a.score));
}

/**
 * 자미두수 대한·유년을 앱 도메인별 경향으로 정규화한다 (교차검증·프롬프트 근거용).
 * 원식 verdict와 같은 '방향 신호' 성격 — 표면 문장은 항상 '~한 편', 용어는 근거에만.
 */
export function deriveZiweiLuckVerdicts(chart: ZiweiChart, luck: ZiweiLuck): ZiweiLuckVerdict[] {
  const out: ZiweiLuckVerdict[] = [];
  if (luck.decade) out.push(...scopeVerdicts(chart, luck.decade, "decade"));
  if (luck.year) out.push(...scopeVerdicts(chart, luck.year, "year"));
  return out;
}

/** 원식을 앱 분야별 좋음/보통/주의 경향으로 정규화한다. */
export function deriveZiweiDomainVerdicts(chart: ZiweiChart): ZiweiDomainVerdict[] {
  const byName = new Map(chart.palaces.map((p) => [p.name, p]));
  const verdicts: ZiweiDomainVerdict[] = [];
  for (const [domain, { label, palace }] of Object.entries(DOMAIN_PALACE)) {
    const p = byName.get(palace);
    if (!p) continue;
    const { score, stars, glosses } = scorePalace(p);
    const tone = toneOf(score);
    const borrowed = p.majorStars.length === 0 ? " (본궁 비어 삼방에서 차성)" : "";
    verdicts.push({
      domain,
      label,
      palace,
      tone,
      score: Math.round(score * 10) / 10,
      stars,
      note: TONE_NOTE[domain][tone],
      evidence: `${palace}궁(${p.branch}) ${glosses.length > 0 ? glosses.join("·") : "주성 없음"}${borrowed} → ${tone}(${Math.round(score * 10) / 10})`,
    });
  }
  return verdicts;
}
