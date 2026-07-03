import type { ConcernCategory, MysticEvidence, MysticReadingResult } from "../../types";
import { INTEREST_WEIGHTING } from "./readingRules";

/**
 * LLM 호출 실패/키 부재 시 사용하는 룰 기반 폴백.
 * 근거(MysticEvidence)만으로 안전한 상담 톤 문장을 조립한다.
 * - 단정·공포·저주·무속·운명확정 표현 금지
 * - 모든 필드를 빈 문자열 없이 채우고, evidence는 최소 1개 이상 남긴다
 * - "내 속을 들여다본 듯" 느껴지도록 결론→근거→현실 장면→보완 구조를 지킨다
 */

const GROUP_TRAIT: Record<string, string> = {
  비겁: "스스로 버티고 밀고 나가는 힘",
  식상: "표현하고 만들어내려는 기운",
  재성: "현실을 손에 쥐고 관리하려는 기운",
  관성: "책임지고 자기를 다잡으려는 기운",
  인성: "받아들이고 안으로 정리하려는 기운",
};

const GROUP_TIRED: Record<string, string> = {
  비겁: "혼자 다 감당하려다 어깨가 먼저 무거워질 수 있습니다",
  식상: "표현하고 싶은 게 쌓였는데 내보낼 곳이 없으면 안이 답답해지기 쉽습니다",
  재성: "결과를 손에 쥐어야 마음이 놓이는 편이라, 성과가 늦으면 초조함이 올라올 수 있습니다",
  관성: "스스로에게 요구하는 기준이 높아, 다 못 했다는 느낌에 눌리기 쉽습니다",
  인성: "생각이 안으로 계속 도는 편이라, 정리되지 않으면 머리가 먼저 지칠 수 있습니다",
};

function firstEl(e: MysticEvidence): string {
  return e.strongElements[0] ?? e.dayMasterElement ?? "";
}

function dominant(e: MysticEvidence): string {
  return e.dominantTenGods[0] ?? "비겁";
}

function evOf(e: MysticEvidence, extra: string[] = []): string[] {
  const base = e.notes.slice(0, 3);
  const merged = [...base, ...extra].filter(Boolean);
  return merged.length > 0 ? merged : ["사주 원국 기준 해석"];
}

const CONCERN_TEXT: Record<ConcernCategory, { title: string; description: string; why: string }> = {
  work: {
    title: "지금 하는 일이 맞는 방향인지에 대한 의심",
    description: "일이 싫은 게 아니라, 이 방향을 계속 가도 되는지가 선명하지 않아 마음 한쪽이 계속 걸려 있는 상태에 가깝습니다.",
    why: "방향이 납득되지 않으면 에너지가 먼저 빠지는 구조라, 이런 의심이 반복해서 올라옵니다.",
  },
  money: {
    title: "돈을 벌고 싶은데 방향이 흐릿한 답답함",
    description: "게으른 게 아니라, 어디에 힘을 쌓아야 돈이 붙는지가 아직 또렷하지 않아 손이 여러 곳으로 흩어지기 쉬운 시기입니다.",
    why: "에너지가 분산되면 성과가 늦게 붙는 흐름이라, 조급함과 답답함이 함께 올라옵니다.",
  },
  relationship: {
    title: "사람에게 기대했다가 실망한 감정",
    description: "말로 크게 표현하진 않지만, 기대했던 온도가 느껴지지 않을 때 마음속에서 조용히 거리를 정리하는 편입니다.",
    why: "관계에서 기대와 실제의 간격에 민감한 편이라, 이런 감정이 반복해서 남습니다.",
  },
  health: {
    title: "몸은 피곤한데 마음은 계속 초조한 상태",
    description: "쉬어도 개운하지 않은 건 몸보다 마음 안쪽이 계속 눌려 있기 때문일 수 있습니다.",
    why: "생각이 안에서 계속 도는 흐름이라, 몸의 피로와 마음의 초조가 함께 갑니다.",
  },
  emotion: {
    title: "괜찮은 척하지만 안쪽이 계속 눌려 있는 느낌",
    description: "겉으로는 정리된 것처럼 보여도, 정작 스스로에게는 감정을 뒤늦게 꺼내 보는 편입니다.",
    why: "감정을 바로 표현하기보다 안에서 오래 정리하는 방식이라, 눌린 느낌이 남습니다.",
  },
  future: {
    title: "시작은 하고 싶은데 끝까지 못 갈까 봐 드는 망설임",
    description: "능력이 없어서가 아니라, 확신이 흔들리면 중간에 방향을 바꾸고 싶어지는 패턴을 스스로 알고 있어 미리 조심하는 것에 가깝습니다.",
    why: "확신이 에너지의 연료라, 그게 흐려질 때를 스스로 경계하게 됩니다.",
  },
  selfWorth: {
    title: "남들 기준에 나를 자꾸 맞춰보게 되는 마음",
    description: "사람에게 실망한 것보다, 기대했던 자신의 모습이 흔들릴 때 더 지치는 편입니다.",
    why: "자기 기준이 높은 편이라, 그 기준에 못 미친다고 느낄 때 자존감이 먼저 흔들립니다.",
  },
};

function pickConcerns(e: MysticEvidence) {
  const order = INTEREST_WEIGHTING[e.interest].emphasizeConcerns;
  const chosen = order.slice(0, 4);
  return chosen.map((cat, i) => ({
    category: cat,
    title: CONCERN_TEXT[cat].title,
    description: CONCERN_TEXT[cat].description,
    whyItAppears: CONCERN_TEXT[cat].why,
    confidence: Math.max(0.5, 0.85 - i * 0.1),
  }));
}

function buildTurningPoints(e: MysticEvidence) {
  const flow = e.monthlyFlow.length > 0 ? e.monthlyFlow : [];
  if (flow.length === 0) {
    return [
      {
        period: `올해(${e.yearGanZhi})`,
        keyword: "숨 고르기",
        opportunity: "덜어낸 자리에 새 흐름이 들어오기 좋은 해입니다.",
        caution: "무리해서 밀어붙이기보다 페이스를 지키는 편이 좋습니다.",
        advice: "한 가지 흐름을 오래 쌓는 데 집중해보세요.",
      },
    ];
  }
  // 대표적인 3~4개 달만 뽑는다 (충/합이 있는 달 우선)
  const notable = flow.filter((m) => m.interactions.length > 0).slice(0, 4);
  const chosen = notable.length > 0 ? notable : flow.filter((_, i) => i % 4 === 0);
  return chosen.map((m) => {
    const hasChong = m.interactions.some((i) => i.includes("충"));
    const hasHe = m.interactions.some((i) => i.includes("합"));
    return {
      period: `${m.month}월(${m.ganZhi})`,
      keyword: hasChong ? "변동" : hasHe ? "연결" : "정리",
      opportunity: hasHe
        ? "주변과 손발이 맞아 협력이 잘 풀리기 쉬운 흐름입니다."
        : "흐트러진 것을 정리하기 좋은 시기입니다.",
      caution: hasChong
        ? "일정이나 계획이 갑자기 바뀌기 쉬우니 여유 시간을 두는 편이 좋습니다."
        : "큰 결정을 서두르기보다 한 박자 늦추는 편이 좋습니다.",
      advice: "이 시기의 변화는 방향을 바꾸기 전 숨을 고르는 신호로 읽어보세요.",
    };
  });
}

export function buildFallbackReading(e: MysticEvidence): MysticReadingResult {
  const el = firstEl(e);
  const dom = dominant(e);
  const domTrait = GROUP_TRAIT[dom] ?? "자기 방식대로 버티는 힘";
  const domTired = GROUP_TIRED[dom] ?? "방향이 흐려지면 몸이 먼저 무거워질 수 있습니다";
  const weak = e.weakElements[0];
  const hourNote = e.hasHour ? [] : ["출생시간을 모르는 경우 시주 기반 세부 해석은 달라질 수 있습니다"];

  return {
    openingOracle: {
      title: "지금 당신의 자리",
      sentence:
        e.strength === "신약"
          ? "지금은 더 밀어붙이는 시기가 아니라, 나를 갉아먹는 것을 하나씩 덜어내야 다음 흐름이 들어오는 때에 가깝습니다."
          : "당신은 쉬고 싶은 게 아니라, 방향이 또렷하지 않아 힘이 흩어지고 있는 상태에 가깝습니다.",
      intensity: e.strength === "신약" ? "high" : "medium",
      evidence: evOf(e, [`${dom} 강함`, `일간 세력: ${e.strength}`]),
    },
    currentState: {
      summary: `요즘은 ${domTrait}이 강하게 올라오는 시기라, ${domTired}.`,
      bodySignal: "해야 할 일은 많은데 방향이 선명하지 않으면 몸이 먼저 무거워질 수 있습니다.",
      emotionalSignal:
        "스트레스를 받는다기보다, 마음 안쪽이 계속 눌려 있는 상태에 가깝습니다. 초조함과 무기력이 번갈아 올라오기 쉽습니다.",
      energyLeak: weak
        ? `${weak} 기운이 약한 편이라, 그 부분을 억지로 채우려 할 때 에너지가 가장 많이 샙니다.`
        : "확신이 흔들리는 지점마다 에너지가 조금씩 새어 나갑니다.",
      advice: "지금은 더 밀어붙이기보다, 에너지가 새는 곳을 줄이는 것이 먼저입니다.",
      evidence: evOf(e, e.hasHour ? [] : hourNote),
    },
    hiddenConcerns: pickConcerns(e),
    outerInnerSelf: {
      outerSelf: "겉으로는 무던하고 알아서 잘하는 사람처럼 보이는 편입니다.",
      innerSelf:
        "사실은 기대했던 사람이 애매하게 굴 때, 그 감정을 마음속에서 오래 정리하는 편입니다.",
      defensePattern:
        "상처받을 때 바로 표현하기보다, 말수를 줄이고 거리를 조용히 벌리는 방식으로 반응합니다.",
      hiddenDesire: "진짜 원하는 건 인정이나 성과보다, 방향이 납득되는 안정감일 수 있습니다.",
      collapsePoint:
        "애써온 것이 나에게 의미 없게 느껴지는 순간, 가장 크게 무너집니다.",
      evidence: evOf(e, [`${dom} 강함`]),
    },
    repeatedPatterns: [
      {
        area: "work",
        pattern: "능력이 없는 게 아니라, 방향이 납득되지 않으면 몸이 먼저 멈추는 편입니다.",
        reason: "왜 해야 하는지가 분명하지 않을 때 에너지가 급격히 떨어지는 구조에 가깝습니다.",
        howToBreak: "일을 시작하기 전에 '이걸 왜 하는지' 한 줄을 먼저 적어두면 흐름이 덜 끊깁니다.",
      },
      {
        area: "relationship",
        pattern: "기대한 온도가 느껴지지 않으면 마음속에서 조용히 거리를 두는 편입니다.",
        reason: "말보다 말투와 거리감에 먼저 반응하는 편이라, 실망이 안에서 먼저 쌓입니다.",
        howToBreak: "거리를 두기 전에 서운함을 한 번은 밖으로 꺼내보면 오해가 줄어듭니다.",
      },
      {
        area: "emotion",
        pattern: "괜찮은 척 정리해두었다가, 뒤늦게 감정이 올라오는 편입니다.",
        reason: "감정을 바로 표현하기보다 안에서 오래 정리하는 방식이기 때문입니다.",
        howToBreak: "그날의 감정을 짧게라도 적어두면 뒤늦게 몰아치는 일이 줄어듭니다.",
      },
    ],
    workAndMoney: {
      moneyAttractionPattern:
        `${el ? `${el} 기운을 살리는 방향에서 ` : ""}한 가지 흐름을 오래 쌓을 때 돈이 뒤늦게 붙는 편입니다.`,
      moneyLeakPattern:
        "확신이 흔들려 중간에 방향을 바꾸고 싶어질 때, 그동안 쌓은 것이 흩어지며 돈이 샙니다.",
      suitableWorkEnvironment: "이유와 방향이 분명하고, 내 페이스를 지킬 수 있는 환경이 잘 맞습니다.",
      unsuitableWorkEnvironment: "납득 없이 밀어붙여야 하거나, 잦은 방향 전환을 요구하는 환경은 오래 버티기 어렵습니다.",
      currentAdvice: "지금은 새 판을 벌리기보다, 이미 쌓아온 하나를 매듭짓는 데 힘을 모으는 편이 좋습니다.",
    },
    relationshipReading: {
      expectationPattern: "관계에서 큰 말보다, 꾸준한 온도와 결이 맞는 느낌을 기대하는 편입니다.",
      hurtPattern: "기대했던 반응이 애매하게 돌아올 때 가장 크게 상처받습니다.",
      closingHeartMoment: "서운함을 두세 번 삼키고 나면, 어느 순간 조용히 마음을 닫습니다.",
      misunderstandingPattern: "표현을 아끼다 보니, 상대가 '괜찮은 줄 알았다'고 오해하기 쉽습니다.",
      advice: "말은 부드럽지만 책임은 흐리는 사람과의 거리는 조금 신중히 두는 편이 좋습니다.",
    },
    yearlyTurningPoints: buildTurningPoints(e),
    avoidNow: [
      {
        title: "지친 상태에서 큰 결정을 내리는 것",
        reason: "몸과 마음이 눌려 있을 때의 판단은 평소보다 방어적으로 기울기 쉽습니다.",
        saferAlternative: "중요한 결정은 컨디션이 회복된 뒤로 신중히 미루는 편이 좋습니다.",
      },
      {
        title: "충동적으로 방향을 바꾸는 것",
        reason: "확신이 흔들릴 때의 방향 전환은 그동안 쌓은 것을 흩을 가능성이 큽니다.",
        saferAlternative: "바꾸고 싶을 때 2주만 같은 흐름을 더 이어보고 판단해보세요.",
      },
    ],
    doNow: [
      {
        title: "오늘 할 수 있는 작은 매듭 하나",
        action: "미뤄둔 일 중 가장 작은 것 하나를 오늘 안에 끝내보세요.",
        reason: "손에 잡히는 완결 하나가 흩어진 에너지를 다시 모아줍니다.",
      },
      {
        title: "이번 주에 정리할 것",
        action: "에너지가 가장 많이 새는 관계나 일 하나를 골라 거리를 조정해보세요.",
        reason: "덜어낸 자리에 다음 흐름이 들어오기 때문입니다.",
      },
      {
        title: "감정 한 줄 적기",
        action: "하루의 끝에 지금 감정을 한 줄로 적어보세요.",
        reason: "뒤늦게 몰아치는 감정을 미리 흘려보내는 데 도움이 됩니다.",
      },
    ],
    closingOracle: {
      sentence: "당신의 운은 멈춘 게 아니라, 방향을 바꾸기 전에 숨을 고르는 중입니다.",
      theme: "정리하는 자리에 새 기회가 들어옵니다.",
    },
  };
}
