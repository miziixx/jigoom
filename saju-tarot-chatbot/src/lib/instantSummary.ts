import type { FiveElementBalance, LuckCycles, SajuChart } from "../types";

/**
 * 계산된 사실(SajuChart/LuckCycles)만으로 즉시(무 API) 만드는 룰 기반 요약.
 *
 * 목적: AI 리딩이 생성되기 전에도, 혹은 생성이 잘려도, 사용자가 읽을 수 있는 해석이 항상 남게 한다.
 * 표면 문장에는 사주 전문용어(간지·십성·충합 등)를 쓰지 않고 쉬운 말로만 옮긴다. (CLAUDE.md 규칙)
 * 계산값을 문장화만 하므로 fortuneFallback과 같은 "근거→문장" 성격이다.
 */

/** 오행을 생활 언어 키워드로 (CLAUDE.md 용어 번역표) */
const ELEMENT_ENERGY: Record<keyof FiveElementBalance, string> = {
  wood: "성장·시작·배움",
  fire: "표현·활력·추진력",
  earth: "안정·책임·현실감",
  metal: "판단·기준·결단",
  water: "생각·감정·휴식",
};

const ELEMENT_KO_LOCAL: Record<keyof FiveElementBalance, string> = {
  wood: "목",
  fire: "화",
  earth: "토",
  metal: "금",
  water: "수",
};

const STRENGTH_PLAIN: Record<string, string> = {
  신강: "스스로 밀고 나가는 힘이 강한 편이라, 방향만 잡히면 추진력이 붙습니다. 다만 혼자 끌어안다 지치기 쉬우니 힘을 덜어낼 곳을 두는 게 좋아요.",
  중화: "한쪽으로 크게 치우치지 않아 균형이 잡힌 편입니다. 상황에 맞게 밀고 당기기가 비교적 자유로워요.",
  신약: "받아들이고 조율하는 힘이 앞서는 편이라, 혼자보다 사람·환경의 도움을 받을 때 잘 풀립니다. 무리한 독주보다 협력이 유리해요.",
};

export interface InstantSummaryLine {
  label: string;
  text: string;
}

export interface InstantSummary {
  lines: InstantSummaryLine[];
}

/** 올해 흐름의 상호작용 개수를 숫자 없이 라벨로 (SajuFactsPanel과 같은 기준) */
function flowLabel(count: number): string {
  if (count <= 0) return "크게 흔들리지 않는 평이한 흐름";
  if (count === 1) return "가벼운 자극이 있는 흐름";
  if (count === 2) return "변화가 감지되는 흐름";
  return "움직임이 큰 흐름";
}

/**
 * 계산 사실을 즉시 요약 문장들로 만든다. 근거가 없으면 null.
 */
export function buildInstantSummary(sajuChart?: SajuChart, luckCycles?: LuckCycles): InstantSummary | null {
  if (!sajuChart) return null;
  const lines: InstantSummaryLine[] = [];

  // 1) 타고난 기운의 중심 (가장 강한 오행)
  const entries = Object.entries(sajuChart.fiveElements) as [keyof FiveElementBalance, number][];
  const sorted = [...entries].sort((a, b) => b[1] - a[1]);
  const strongest = sorted[0];
  const weakest = sorted[sorted.length - 1];
  if (strongest && strongest[1] > 0) {
    lines.push({
      label: "타고난 중심",
      text: `${ELEMENT_ENERGY[strongest[0]]} 쪽 기운이 가장 두드러집니다. 이 결이 성격과 일하는 방식에 가장 자주 드러나요.`,
    });
  }
  if (weakest && weakest[1] === 0) {
    lines.push({
      label: "채우면 좋은 결",
      text: `${ELEMENT_ENERGY[weakest[0]]}(${ELEMENT_KO_LOCAL[weakest[0]]}) 쪽은 비어 있는 편이라, 의식적으로 채워두면 균형에 도움이 됩니다.`,
    });
  }

  // 2) 힘의 세기 (신강/중화/신약)
  if (sajuChart.strength) {
    const plain = STRENGTH_PLAIN[sajuChart.strength.label];
    if (plain) lines.push({ label: "힘의 균형", text: plain });
  }

  // 3) 일주 성향 (이미 쉬운 말로 계산돼 있음)
  if (sajuChart.iljuTrait) {
    lines.push({ label: "기질 한 줄", text: sajuChart.iljuTrait });
  }

  // 4) 올해 흐름 (세운 상호작용 개수 → 라벨)
  if (luckCycles) {
    const yearCount = luckCycles.luckInteractions?.length ?? 0;
    lines.push({
      label: "올해 흐름",
      text: `올해는 ${flowLabel(yearCount)}으로 보입니다. ${
        yearCount >= 2
          ? "변화의 신호가 있는 시기이니, 큰 결정은 근거를 한 번 더 확인하고 움직이면 좋아요."
          : "무리하게 판을 흔들기보다, 하던 흐름을 다지는 쪽이 유리한 시기예요."
      }`,
    });
  }

  // 5) 신살 (있으면 이름 없이 뜻풀이만 1~2개)
  if (sajuChart.sinsal && sajuChart.sinsal.length > 0) {
    const glosses = sajuChart.sinsal.slice(0, 2).map((s) => s.gloss).filter(Boolean);
    if (glosses.length > 0) {
      lines.push({ label: "눈에 띄는 결", text: glosses.join(" 그리고 ") + "." });
    }
  }

  return lines.length > 0 ? { lines } : null;
}
