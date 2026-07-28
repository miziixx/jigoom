import type { MonthFlowInfo } from "../types/index.js";
import {
  BENEFIT_KINDS,
  KIND_NUANCE,
  POSITION_MEANING,
  parseInteraction,
  type InteractionKind,
  type ParsedInteraction,
  type PositionLabel,
} from "./eventEngine.js";

/**
 * 월별 흐름 문구 생성 (순수 카피 레이어).
 *
 * 이전에는 MonthlyFlowChart/SajuFactsPanel/ActionCalendar 세 곳이 각자
 * interactions.length(개수)만 보고 4~5개 고정 문구 중 하나를 반복해서 골랐다.
 * 이 모듈은 이미 계산된 interactions 문자열(예: "일간-월운 을경합(금)")을
 * eventEngine.ts의 파서로 다시 해석해, 어떤 관계(합/충/형/파/해)가 어느 자리
 * (일간/일지/월지 등 = 나·배우자·직업 등)에서 일어나는지가 드러나는 문장을 만든다.
 * saju.ts/eventEngine.ts의 계산 로직은 건드리지 않는다 — 표면 문구만 바꾼다.
 */

/** 여러 상호작용 중 가장 눈에 띄는 것을 고르는 우선순위 (충 > 형 > 파/해/자형 > 삼합/방합 > 합/반합) */
const KIND_SEVERITY: Record<InteractionKind, number> = {
  충: 6,
  형: 5,
  파: 4,
  해: 4,
  자형: 4,
  삼합: 3,
  방합: 3,
  합: 2,
  반합: 2,
};

/** 궁위 → 짧은 chip용 단어 */
const PILLAR_SHORT: Record<PositionLabel, string> = {
  연간: "사회",
  연지: "기반",
  월간: "직업",
  월지: "직업",
  일간: "자신",
  일지: "관계",
  시간: "미래",
  시지: "자녀",
};

/** 관계 종류 → 짧은 chip용 단어 */
const KIND_SHORT: Record<InteractionKind, string> = {
  충: "충돌",
  형: "압박",
  파: "어긋남",
  해: "방해",
  합: "결합",
  삼합: "결집",
  반합: "결집",
  방합: "결집",
  자형: "자초 긴장",
};

function parseAll(interactions: string[]): ParsedInteraction[] {
  return interactions.map(parseInteraction).filter((x): x is ParsedInteraction => x !== null);
}

function pickTop(parsed: ParsedInteraction[]): ParsedInteraction | null {
  if (parsed.length === 0) return null;
  return [...parsed].sort((a, b) => (KIND_SEVERITY[b.kind] ?? 0) - (KIND_SEVERITY[a.kind] ?? 0))[0];
}

function primaryPillar(positions: PositionLabel[]): PositionLabel | null {
  return positions[0] ?? null;
}

function severityLevel(count: number): 0 | 1 | 2 | 3 {
  if (count >= 4) return 3;
  if (count >= 2) return 2;
  if (count === 1) return 1;
  return 0;
}

/** 한글 음절의 받침(종성) 유무로 "을/를" 조사를 고른다. */
function withObjectParticle(text: string): string {
  const code = text.charCodeAt(text.length - 1);
  const hasBatchim = code >= 0xac00 && code <= 0xd7a3 && (code - 0xac00) % 28 !== 0;
  return `${text}${hasBatchim ? "을" : "를"}`;
}

/** 1~12월 흐름 차트/그리드용: 매달 실제로 어떤 관계·자리가 움직이는지 구체적으로 서술한다. */
export function describeMonthFlow(mf: MonthFlowInfo): { label: string; detail: string; level: 0 | 1 | 2 | 3 } {
  const level = severityLevel(mf.interactions.length);
  const parsed = parseAll(mf.interactions);
  const top = pickTop(parsed);

  if (!top) {
    return {
      label: "잔잔함",
      detail: "원국과 새로 부딪히거나 묶이는 관계가 없어, 평소 리듬을 유지하기 좋은 달입니다.",
      level,
    };
  }

  const pillar = primaryPillar(top.positions);
  const nuance = KIND_NUANCE[top.kind];
  const label = pillar ? `${PILLAR_SHORT[pillar]} 쪽 ${KIND_SHORT[top.kind]}` : KIND_SHORT[top.kind];

  let detail = pillar
    ? `${withObjectParticle(POSITION_MEANING[pillar])} 중심으로 ${nuance}이 생기기 쉬운 달입니다.`
    : `이번 달은 ${nuance}입니다.`;

  const second = parsed.find((p) => p !== top && primaryPillar(p.positions) !== pillar);
  const secondPillar = second ? primaryPillar(second.positions) : null;
  if (secondPillar) detail += ` ${POSITION_MEANING[secondPillar]}도 함께 움직이기 쉬워요.`;

  return { label, detail, level };
}

/** 궁위를 실행 계획용 큰 분류(자신/관계/직업/사회/가족·자녀)로 묶는다. */
type ActionGroup = "자신" | "관계" | "직업" | "사회" | "가족·자녀";

const PILLAR_ACTION_GROUP: Record<PositionLabel, ActionGroup> = {
  일간: "자신",
  일지: "관계",
  월간: "직업",
  월지: "직업",
  연간: "사회",
  연지: "사회",
  시간: "가족·자녀",
  시지: "가족·자녀",
};

const CARE_ACTION: Record<ActionGroup, string> = {
  자신: "컨디션과 감정 기복이 커질 수 있어요. 큰 결정은 하루 더 두고 판단하세요.",
  관계: "가까운 관계에서 부딪히거나 자리가 흔들릴 수 있어요. 약속·조건을 다시 확인하세요.",
  직업: "직장·역할 쪽에 변동 신호가 있어요. 큰 계약이나 이직 결정은 조건을 재확인하세요.",
  사회: "바깥 활동이나 인간관계 전반에서 마찰이 생기기 쉬워요. 감정적으로 바로 결정하지 마세요.",
  "가족·자녀": "가족이나 마무리해야 할 일에서 조정이 필요해요. 계획을 작게 수정하는 편이 좋아요.",
};

const MOVE_ACTION: Record<ActionGroup, string> = {
  자신: "스스로 판단 기준이 새로 잡히는 시기예요. 방향을 정하기 좋은 달입니다.",
  관계: "사람과 인연이 이어지기 좋은 달이에요. 약속과 역할은 분명히 하세요.",
  직업: "직업·일에서 새 제안이나 협업이 들어오기 쉬워요. 조건은 문서로 남기세요.",
  사회: "바깥 활동에서 좋은 연결이 생기기 쉬운 달이에요.",
  "가족·자녀": "가족이나 자녀 쪽 일이 순조롭게 풀리기 쉬운 달이에요.",
};

const CARE_LABEL: Record<ActionGroup, string> = {
  자신: "컨디션 관리",
  관계: "관계 점검",
  직업: "직업 점검",
  사회: "관계망 점검",
  "가족·자녀": "가족 조정",
};

const MOVE_LABEL: Record<ActionGroup, string> = {
  자신: "기준 재정비",
  관계: "관계 형성",
  직업: "일 확장",
  사회: "관계망 확장",
  "가족·자녀": "가족 화합",
};

/** "월별 실행 캘린더"용: 어느 자리가 움직이는지에 따라 구체적인 행동을 제안한다. */
export function describeMonthAction(mf: MonthFlowInfo): { tone: "quiet" | "move" | "care"; label: string; action: string } {
  const parsed = parseAll(mf.interactions);
  const top = pickTop(parsed);

  if (!top) {
    return { tone: "quiet", label: "기본기 정리", action: "새로 벌리기보다 루틴, 기록, 정리, 회복을 챙기세요." };
  }

  const isMove = BENEFIT_KINDS.has(top.kind);
  const pillar = primaryPillar(top.positions);
  const group: ActionGroup = pillar ? PILLAR_ACTION_GROUP[pillar] : "자신";

  return isMove
    ? { tone: "move", label: MOVE_LABEL[group], action: MOVE_ACTION[group] }
    : { tone: "care", label: CARE_LABEL[group], action: CARE_ACTION[group] };
}
