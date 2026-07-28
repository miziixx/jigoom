import type { Gender, LifeDomain, LuckCycles, SajuChart } from "../types/index.js";
import { buildEventForecast } from "./eventEngine.js";

/**
 * "지금 저울질 신호" 엔진 (무 API·결정론).
 *
 * 목적:
 *   사용자가 가장 소름 돋아 하는 지점 중 하나 — "내가 지금 이런 선택을 고민하는 걸 어떻게 알았지?".
 *   사주 성향(psychLayer=어떻게 선택하나)이나 지금 마음(nowMind=지금 어떤 마음인가)과 달리,
 *   이 엔진은 "지금 어느 분야가 움직여서 무슨 선택을 저울질하기 쉬운가"를 계산한다.
 *   eventEngine이 이미 계산한 '지금 활성 분야(activeDomains)'를 선택 고민 언어로 옮긴다.
 *
 * 안전 원칙(중요):
 *   맞히려 들다 틀리면 신뢰가 깨진다. 그래서 '단정'이 아니라 '되짚어 묻는' 톤으로만 쓴다.
 *   상위 1~2개 활성 분야만, "요즘 ~를 저울질하기 쉬운 때"처럼 경향으로 제시한다.
 *   사용자가 질문/고민을 직접 적었으면 그 질문이 우선이고 이건 보조일 뿐이다.
 *   saju.ts를 import하지 않는다(번들 방지). eventEngine의 buildEventForecast만 재사용.
 */

/** 분야 × 흐름 성격(기회/주의/혼조) → 지금 저울질하기 쉬운 선택 (쉬운 말, 사주 용어 금지) */
const DELIBERATION: Record<LifeDomain, { caution: string; opportunity: string; mixed: string }> = {
  career: {
    caution: "지금 이 일을 계속할지 내려놓을지, 버틸지 정리할지를 두고 마음이 오가기 쉬운 때입니다.",
    opportunity: "지금 자리를 옮기거나 역할을 넓힐지, 들어온 기회를 잡을지 저울질하기 쉬운 때입니다.",
    mixed: "지금 자리를 지킬지 새로 움직일지, 일에서 방향을 두고 고민이 들기 쉬운 때입니다.",
  },
  money: {
    caution: "큰 지출·계약·돈을 묶는 결정을 앞두고, 지를지 미룰지 재고 있기 쉬운 때입니다.",
    opportunity: "지금 돈이 될 기회를 잡을지, 규모를 키울지 저울질하기 쉬운 때입니다.",
    mixed: "돈을 쓸지 지킬지, 벌일지 아낄지를 두고 마음이 오가기 쉬운 때입니다.",
  },
  love: {
    caution: "관계를 이어갈지 한 발 물러설지, 마음을 더 열지 말지를 저울질하기 쉬운 때입니다.",
    opportunity: "관계를 한 단계 진전시킬지, 새 인연에 마음을 열지 고민이 들기 쉬운 때입니다.",
    mixed: "다가갈지 거리를 둘지, 관계에서 어느 쪽으로 갈지 마음이 오가기 쉬운 때입니다.",
  },
  health: {
    caution: "몸을 더 밀어붙일지 쉬어갈지, 지금 페이스를 두고 고민이 들기 쉬운 때입니다.",
    opportunity: "생활 리듬이나 운동·습관을 새로 잡을지 저울질하기 쉬운 때입니다.",
    mixed: "무리를 이어갈지 속도를 늦출지 마음이 오가기 쉬운 때입니다.",
  },
  family: {
    caution: "집안 문제에서 내 몫을 어디까지 질지, 선을 그을지를 저울질하기 쉬운 때입니다.",
    opportunity: "가족 안에서 역할을 새로 정할지, 관계를 풀지 고민이 들기 쉬운 때입니다.",
    mixed: "떠안을지 나눌지, 가족 일에서 어느 선까지 갈지 마음이 오가기 쉬운 때입니다.",
  },
  move: {
    caution: "옮길지 머물지, 지금 환경을 바꿀지 지킬지를 저울질하기 쉬운 때입니다.",
    opportunity: "이사·이동으로 환경을 새로 바꿀지 고민이 들기 쉬운 때입니다.",
    mixed: "자리를 옮길지 지금을 지킬지 마음이 오가기 쉬운 때입니다.",
  },
  startup: {
    caution: "새로 벌일지 지금을 지킬지, 독립을 감행할지를 저울질하기 쉬운 때입니다.",
    opportunity: "새 일을 벌이거나 독립할지, 지금 아이디어를 밀지 고민이 들기 쉬운 때입니다.",
    mixed: "벌일지 지킬지, 지금 판을 키울지 마음이 오가기 쉬운 때입니다.",
  },
};

const CTA_HEAD: Record<LifeDomain, string> = {
  career: "일·자리",
  money: "돈·계약",
  love: "관계",
  health: "몸·컨디션",
  family: "가족·집안",
  move: "이동·환경",
  startup: "새 일·독립",
};

export interface DeliberationSignal {
  domain: LifeDomain;
  label: string;
  balance: "opportunity" | "caution" | "mixed" | "calm";
  hypothesis: string;
}

export interface Deliberation {
  headline: string;
  signals: DeliberationSignal[];
  evidence: string[];
}

export function buildDeliberation(chart?: SajuChart, luck?: LuckCycles, gender?: Gender): Deliberation | null {
  if (!chart) return null;
  const forecast = buildEventForecast(chart, luck, gender);
  if (!forecast || forecast.activeDomains.length === 0) return null;

  const signals: DeliberationSignal[] = [];
  for (const key of forecast.activeDomains.slice(0, 2)) {
    const d = forecast.domains.find((x) => x.domain === key);
    if (!d) continue;
    const balance = d.scores.balance;
    if (balance === "calm") continue;
    const hypothesis = DELIBERATION[key][balance];
    signals.push({ domain: key, label: d.label, balance, hypothesis });
  }
  if (signals.length === 0) return null;

  const headTopics = signals.map((s) => CTA_HEAD[s.domain]);
  const headline = `요즘 마음이 가장 많이 오가는 건 ${headTopics.join(", ")} 쪽입니다.`;

  const evidence = signals.map(
    (s) => `${s.label}: 지금 활성 분야(${s.balance === "opportunity" ? "기회형" : s.balance === "caution" ? "주의형" : "혼조형"})로 계산됨`,
  );

  return { headline, signals, evidence };
}

/** 프롬프트 근거 블록으로 직렬화한다. */
export function formatDeliberation(d: Deliberation): string {
  const lines = [d.headline];
  for (const s of d.signals) lines.push(`- ${s.hypothesis}`);
  if (d.evidence.length > 0) lines.push(`(근거) ${d.evidence.join("; ")}`);
  return lines.join("\n");
}
