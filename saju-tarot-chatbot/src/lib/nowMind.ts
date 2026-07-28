import type { LuckCycles, SajuChart } from "../types/index.js";
import { groupOf, tenGodOf, ZHI_MAIN_STEM_TABLE, type TenGodGroup } from "./eventEngine.js";

/**
 * "지금 마음" 엔진 (무 API·결정론).
 *
 * 목적:
 *   사주는 "타고난 성향"까지는 잘 번역하지만, 사용자가 가장 소름 돋아 하는 지점 —
 *   "지금 내가 이런 생각을 하는 걸 어떻게 알았지?" — 는 지금 시점(세운·월운)이 이 사람의
 *   구조에 겹쳐 특히 어떤 마음을 끌어올리는지를 계산해야 나온다. 지금 그 계산은 LLM에
 *   통째로 맡겨져 일반론으로 흐르고 있었다. 이 모듈이 그 "지금 올라오는 마음"을 못박는다.
 *
 * 원칙(CLAUDE.md):
 *   - 계산은 결정론, 표면은 쉬운 말, 절대적 길흉·공포·단정 금지.
 *   - "이런 마음이 든다"가 아니라 "이런 마음이 올라오기 쉬운 때"까지만(경향).
 *   - 사주 용어는 근거(evidence)에만 두고, 표면 문장(mind/headline)에는 절대 쓰지 않는다.
 *   - saju.ts를 import하지 않는다(무거운 lunar-javascript 번들 방지). 십성 판정은 eventEngine의
 *     검증된 tenGodOf/groupOf를 재사용하고, 작은 상수 표만 인라인한다.
 *
 * 기존 lifestyleGuide.ts의 TodayEnergy("오늘 기운")와 겹치지 않는다:
 *   - TodayEnergy = 오늘 일진 기운에 맞춘 "생활 처방"(색·행동).
 *   - NowMind      = 세운·월운이 이 구조에 끌어올리는 "지금의 심리 상태".
 */

type Element = "wood" | "fire" | "earth" | "metal" | "water";

const GAN_WUXING: Record<string, Element> = {
  갑: "wood", 을: "wood", 병: "fire", 정: "fire", 무: "earth",
  기: "earth", 경: "metal", 신: "metal", 임: "water", 계: "water",
};
const ZHI_WUXING: Record<string, Element> = {
  자: "water", 축: "earth", 인: "wood", 묘: "wood", 진: "earth", 사: "fire",
  오: "fire", 미: "earth", 신: "metal", 유: "metal", 술: "earth", 해: "water",
};
const KO_TO_ELEMENT: Record<string, Element> = { 목: "wood", 화: "fire", 토: "earth", 금: "metal", 수: "water" };

/** 발산형(밖으로 벌이고 밀어붙이는 마음). 나머지(관성·인성)는 수렴형으로 본다. */
const OUTWARD: TenGodGroup[] = ["식상", "재성", "비겁"];

type Tone = "energized" | "strained" | "neutral";

/** 십성 그룹이 지금 끌어올리는 마음. 시점 기운이 보완 기운이면 energized, 부담 기운이면 strained. */
const DRIVE_MIND: Record<TenGodGroup, Record<Tone, string>> = {
  비겁: {
    energized: "요즘은 남에게 기대기보다 내 힘으로 밀어붙여 증명하고 싶은 마음이 세게 올라옵니다.",
    strained: "요즘은 남과 비교되거나 내 몫을 뺏기는 느낌에 예민해지고, 혼자 짊어지려다 지치기 쉽습니다.",
    neutral: "요즘은 내 페이스대로 하고 싶은 마음과 주변과의 거리 조절 사이에서 저울질하게 됩니다.",
  },
  식상: {
    energized: "요즘은 안에 담아두기보다 밖으로 꺼내 만들고 새로 시작하고 싶은 근질거림이 커집니다.",
    strained: "요즘은 하고 싶은 말과 벌이고 싶은 일은 많은데 막상 풀 데가 없어 답답함이 쌓이기 쉽습니다.",
    neutral: "요즘은 새로 벌이고 싶은 마음과 지금을 지키려는 마음이 함께 오갑니다.",
  },
  재성: {
    energized: "요즘은 결과와 숫자로 나를 증명하고 싶고, 현실적으로 뭐가 남는지 계산하려는 마음이 강해집니다.",
    strained: "요즘은 돈·성과가 마음처럼 안 잡혀 초조하고, 관계나 선택까지 손익으로 재게 되기 쉽습니다.",
    neutral: "요즘은 현실 조건을 따지는 마음과 마음 가는 대로 하고 싶은 마음이 부딪힙니다.",
  },
  관성: {
    energized: "요즘은 자리를 잡고 인정받고 싶은 마음, 제대로 해내야 한다는 책임감이 앞섭니다.",
    strained: "요즘은 해야 할 것과 눈치 볼 것에 눌려, 내 자리가 조여오는 듯한 압박이 큽니다.",
    neutral: "요즘은 책임을 지려는 마음과 거기서 벗어나고 싶은 마음 사이에서 마음이 무겁습니다.",
  },
  인성: {
    energized: "요즘은 벌이기보다 배우고 정리하며, 잠시 물러나 나를 채우고 싶은 마음이 큽니다.",
    strained: "요즘은 결정을 자꾸 미루고 더 알아보려 하며, 기대고 싶은데 마땅치 않아 생각만 많아지기 쉽습니다.",
    neutral: "요즘은 더 알아보고 싶은 신중함과 이제는 움직여야 한다는 마음이 오갑니다.",
  },
};

export interface NowMindDrive {
  scope: "세운" | "월운";
  ganZhi: string;
  /** 내부 근거용 십성 그룹 (표면 노출 금지) */
  group: TenGodGroup;
  tone: Tone;
  mind: string;
}

export interface NowMind {
  /** 첫 점괘/질문 중심 핵심을 열 때 축으로 삼을, 지금 특히 올라오기 쉬운 마음 한 줄 */
  headline: string;
  /** 세운·월운이 끌어올리는 마음 (최대 2개, 세운 우선) */
  drives: NowMindDrive[];
  /** 하고 싶은 마음(재료) vs 실제 낼 힘(신강/신약) 사이의 속 긴장 */
  tension: string | null;
  /** 지금 흔들리는 자리 (운과 원국의 충·형·파·해) */
  shaken: string | null;
  /** 전문가 근거 보기용 (간지·십성·강약) */
  evidence: string[];
}

const YONG_ELEMENTS = (chart: SajuChart): Set<Element> => {
  const y = chart.yongshin;
  const list = [...(y?.yongshin ?? []), ...(y?.heesin ?? []), ...(y?.supportive ?? [])];
  return new Set(list.map((k) => KO_TO_ELEMENT[k]).filter((e): e is Element => Boolean(e)));
};
const AVOID_ELEMENTS = (chart: SajuChart): Set<Element> =>
  new Set((chart.yongshin?.unfavorable ?? []).map((k) => KO_TO_ELEMENT[k]).filter((e): e is Element => Boolean(e)));

function toneOf(el: Element | undefined, yong: Set<Element>, avoid: Set<Element>): Tone {
  if (!el) return "neutral";
  if (yong.has(el)) return "energized";
  if (avoid.has(el)) return "strained";
  return "neutral";
}

/** 한 시점 간지에서 지금 드러나는 마음의 축(십성 그룹)과 그 기운의 방향(tone)을 뽑는다. */
function risingFrom(
  scope: NowMindDrive["scope"],
  ganZhi: string | null | undefined,
  dayGan: string,
  yong: Set<Element>,
  avoid: Set<Element>,
): NowMindDrive | null {
  if (!ganZhi || ganZhi.length < 2) return null;
  const gan = ganZhi[0];
  const zhi = ganZhi[1];
  // 천간(밖으로 드러나는 마음)을 우선, 없으면 지지 정기(속에 흐르는 마음)로.
  const stemGroup = groupOf(tenGodOf(dayGan, gan));
  const mainStem = ZHI_MAIN_STEM_TABLE[zhi];
  const branchGroup = mainStem ? groupOf(tenGodOf(dayGan, mainStem)) : null;
  const group = stemGroup ?? branchGroup;
  if (!group) return null;
  const el = stemGroup ? GAN_WUXING[gan] : ZHI_WUXING[zhi];
  const tone = toneOf(el, yong, avoid);
  return { scope, ganZhi, group, tone, mind: DRIVE_MIND[group][tone] };
}

function buildTension(strengthLabel: string | undefined, group: TenGodGroup): string | null {
  if (!strengthLabel) return null;
  const weak = strengthLabel.includes("신약");
  const strong = strengthLabel.includes("신강");
  const outward = OUTWARD.includes(group);
  if (weak && outward)
    return "마음은 밖으로 벌이고 싶은데 정작 밀어붙일 힘은 아껴 써야 하는 때라, 하고 싶은 마음과 실제로 낼 수 있는 힘 사이에서 자꾸 브레이크가 걸립니다.";
  if (weak && !outward)
    return "가뜩이나 에너지를 아껴야 하는 때에 눌리고 물러서는 마음까지 겹쳐, 평소보다 쉽게 지치고 미루게 되기 쉽습니다.";
  if (strong && !outward)
    return "조심하고 눌러 담으려는 마음과, 그냥 밀어붙이고 싶은 힘이 속에서 부딪혀 답답할 수 있습니다.";
  if (strong && outward)
    return "하고 싶은 마음도 그걸 밀어붙일 힘도 같이 세지는 때라, 한번 방향을 정하면 과속하기 쉽습니다.";
  return null;
}

const POSITIONS = ["연간", "연지", "월간", "월지", "일간", "일지", "시간", "시지"] as const;
const POSITION_MEANING: Record<string, string> = {
  연간: "바깥 활동·사회의 자리",
  연지: "터전·기반의 자리",
  월간: "직업·사회활동의 자리",
  월지: "직업·터전의 자리",
  일간: "나 자신",
  일지: "가장 가까운 관계·배우자의 자리",
  시간: "미래 계획의 자리",
  시지: "마무리·말년의 자리",
};
const SHAKE_KIND: Array<{ key: string; word: string }> = [
  { key: "충", word: "부딪혀 자리가 한 번 바뀌는" },
  { key: "형", word: "속으로 압박이 쌓이는" },
  { key: "파", word: "계획이 어긋나 손보게 되는" },
  { key: "해", word: "은근한 오해·엇갈림이 끼는" },
];

/** 운과 원국이 지금 새로 맺는 충·형·파·해에서 "흔들리는 자리"를 한 줄로. */
function buildShaken(luck: LuckCycles): string | null {
  for (const raw of luck.luckInteractions ?? []) {
    const kind = SHAKE_KIND.find((k) => raw.includes(k.key));
    if (!kind) continue;
    const hitPos = POSITIONS.filter((p) => raw.includes(p)).map((p) => POSITION_MEANING[p]);
    const where = hitPos.length > 0 ? [...new Set(hitPos)].join(", ") : "익숙한 자리 하나";
    return `요즘 ${where}가 ${kind.word} 흔들림이 드는 시기라, 마음이 한 번씩 크게 출렁일 수 있습니다.`;
  }
  return null;
}

export function buildNowMind(chart?: SajuChart, luck?: LuckCycles): NowMind | null {
  if (!chart || !luck) return null;
  const dayGan = chart.dayMasterGan;
  if (!dayGan) return null;

  const yong = YONG_ELEMENTS(chart);
  const avoid = AVOID_ELEMENTS(chart);

  const raw = [
    risingFrom("세운", luck.yearGanZhi, dayGan, yong, avoid),
    risingFrom("월운", luck.monthGanZhi, dayGan, yong, avoid),
  ].filter((r): r is NowMindDrive => r !== null);
  if (raw.length === 0) return null;

  // 세운 우선, 같은 마음 축이 겹치면 하나로 합친다.
  const drives: NowMindDrive[] = [];
  for (const r of raw) {
    if (drives.some((d) => d.group === r.group)) continue;
    drives.push(r);
  }

  const dominant = drives[0];
  const tension = buildTension(chart.strength?.label, dominant.group);
  const shaken = buildShaken(luck);

  const headline = tension
    ? `${dominant.mind} 다만 ${tension.replace(/^([^,]*마음)은/, "그 마음은")}`
    : dominant.mind;

  const evidence = [
    ...drives.map((d) => `${d.scope} ${d.ganZhi} → ${d.group} 계열이 지금 마음을 끌어올림(${d.tone})`),
    chart.strength ? `강약 ${chart.strength.label}: ${chart.strength.detail}` : "",
    shaken ? `운·원국 상호작용: ${(luck.luckInteractions ?? []).slice(0, 3).join(", ")}` : "",
  ].filter(Boolean);

  return { headline, drives, tension, shaken, evidence };
}

/** 프롬프트 근거 블록으로 직렬화한다. */
export function formatNowMind(now: NowMind): string {
  const lines = [`지금 특히 올라오기 쉬운 마음: ${now.headline}`];
  for (const d of now.drives) lines.push(`- ${d.mind}`);
  if (now.tension) lines.push(`지금의 속 긴장: ${now.tension}`);
  if (now.shaken) lines.push(`지금 흔들리는 자리: ${now.shaken}`);
  if (now.evidence.length > 0) lines.push(`(근거) ${now.evidence.join("; ")}`);
  return lines.join("\n");
}
