import type { TarotCardDefinition } from "../types";

export interface TarotSymbolism {
  archetype: string;
  symbols: string[];
  imagery: string;
  numberTone: string;
  suitTone: string;
  relationshipTone: string;
}

const MAJOR_ARCHETYPES: Record<number, string> = {
  0: "순수한 시작과 아직 정해지지 않은 가능성",
  1: "의지를 현실로 바꾸는 창조자",
  2: "겉으로 드러나지 않은 직관과 침묵의 지혜",
  3: "풍요, 돌봄, 감각적으로 자라나는 힘",
  4: "질서, 경계, 책임을 세우는 힘",
  5: "전통, 약속, 관계 안의 규칙",
  6: "끌림과 선택, 마음과 가치관의 일치",
  7: "방향을 정하고 끌고 가는 의지",
  8: "강압이 아니라 부드러움으로 다스리는 힘",
  9: "혼자 물러나 본질을 확인하는 시간",
  10: "흐름의 전환과 피할 수 없는 사이클",
  11: "균형, 책임, 원인과 결과의 확인",
  12: "멈춤, 양보, 다른 각도에서 보는 통찰",
  13: "끝맺음과 다음 국면으로 넘어가는 문",
  14: "서로 다른 것을 섞어 균형을 찾는 과정",
  15: "집착, 욕망, 끊기 어려운 패턴",
  16: "무너져야 보이는 진실과 갑작스러운 각성",
  17: "상처 뒤의 회복, 희망, 다시 믿는 마음",
  18: "불확실함, 무의식, 두려움과 상상의 그림자",
  19: "명확함, 활력, 숨기지 않는 기쁨",
  20: "재평가, 부름, 과거를 정리하고 일어나는 순간",
  21: "완성, 통합, 하나의 주기가 닫히는 자리",
};

const MAJOR_SYMBOLS: Record<number, string[]> = {
  0: ["절벽", "작은 짐", "하얀 꽃", "새 길"],
  1: ["위와 아래", "도구 네 가지", "집중된 손", "의지"],
  2: ["기둥", "장막", "달", "숨은 지식"],
  3: ["정원", "밀밭", "왕관", "풍요"],
  4: ["왕좌", "산", "갑옷", "질서"],
  5: ["열쇠", "제자", "의식", "규범"],
  6: ["두 사람", "천사", "선택", "가치관"],
  7: ["두 마리 스핑크스", "전차", "방향", "통제"],
  8: ["사자", "무한대", "부드러운 손", "인내"],
  9: ["등불", "지팡이", "눈 덮인 산", "고독"],
  10: ["바퀴", "사이클", "상승과 하강", "전환"],
  11: ["저울", "검", "곧은 자세", "책임"],
  12: ["거꾸로 매달림", "후광", "정지", "관점 전환"],
  13: ["해골 기사", "깃발", "강", "새벽"],
  14: ["두 컵", "물의 흐름", "한 발은 물에", "조율"],
  15: ["사슬", "그림자", "욕망", "속박"],
  16: ["번개", "무너지는 탑", "추락", "충격"],
  17: ["별", "물 붓기", "나체의 진실함", "회복"],
  18: ["달", "개와 늑대", "가재", "안개 낀 길"],
  19: ["태양", "아이", "말", "해바라기"],
  20: ["나팔", "깨어나는 사람들", "부름", "재평가"],
  21: ["월계관", "춤추는 인물", "네 생물", "완성"],
};

const SUIT_TONES: Record<string, string> = {
  완드: "행동, 열정, 속도, 일이나 욕망의 불씨",
  컵: "감정, 관계, 애정, 마음의 교류",
  소드: "생각, 말, 판단, 갈등과 소통",
  펜타클: "현실, 돈, 시간, 몸으로 확인되는 안정",
  메이저: "일시적 기분보다 큰 흐름과 주제",
};

const RELATIONSHIP_BY_SUIT: Record<string, string> = {
  완드: "관계에서는 끌림과 속도가 빠르지만, 감정 확인보다 행동이 앞설 수 있습니다.",
  컵: "관계에서는 마음의 교류와 애정 표현이 핵심이며, 기대와 서운함도 함께 커질 수 있습니다.",
  소드: "관계에서는 말, 해석, 거리감이 중요하며, 생각이 많아져 오해가 생기기 쉽습니다.",
  펜타클: "관계에서는 꾸준함, 현실 조건, 시간 투자, 안정감이 핵심입니다.",
  메이저: "관계에서는 두 사람의 태도보다 더 큰 주제나 전환점이 드러납니다.",
};

const NUMBER_TONES: Record<string, string> = {
  Ace: "씨앗과 시작. 아직 작지만 방향을 잡으면 커질 힘입니다.",
  Two: "둘 사이의 균형과 선택. 상대와 나, 두 축을 맞추는 단계입니다.",
  Three: "확장과 드러남. 혼자 품던 것이 밖으로 나오기 시작합니다.",
  Four: "안정과 정체. 기반은 생기지만 변화가 느려질 수 있습니다.",
  Five: "충돌과 흔들림. 불편함을 통해 구조를 다시 보게 됩니다.",
  Six: "회복과 조정. 균형을 되찾거나 인정받는 흐름입니다.",
  Seven: "시험과 선택지. 무엇을 믿고 밀고 갈지 정해야 합니다.",
  Eight: "움직임과 반복 훈련. 속도가 붙거나 패턴이 굳어집니다.",
  Nine: "완성 직전의 긴장. 거의 왔지만 피로와 기대가 같이 큽니다.",
  Ten: "한 주기의 완성. 다음 단계로 넘어가기 전 정리가 필요합니다.",
  Page: "서툴지만 새로운 신호. 메시지, 호기심, 배움의 시작입니다.",
  Knight: "움직이는 힘. 접근 방식이 빠르거나 한 방향으로 몰립니다.",
  Queen: "받아들이고 돌보는 성숙한 방식. 분위기와 감정 관리가 중요합니다.",
  King: "통제하고 책임지는 성숙한 방식. 기준과 결정권이 부각됩니다.",
};

function englishName(card: TarotCardDefinition): string {
  return card.name.split(" (")[0];
}

export function tarotSuitOf(card: TarotCardDefinition): string {
  const name = englishName(card);
  if (name.includes("Wands")) return "완드";
  if (name.includes("Cups")) return "컵";
  if (name.includes("Swords")) return "소드";
  if (name.includes("Pentacles")) return "펜타클";
  return "메이저";
}

function rankOf(card: TarotCardDefinition): string {
  return englishName(card).split(" of ")[0];
}

export function describeTarotSymbolism(card: TarotCardDefinition): TarotSymbolism {
  const suit = tarotSuitOf(card);
  if (card.arcana === "major") {
    const symbols = card.symbols ?? MAJOR_SYMBOLS[card.id] ?? ["큰 전환", "원형적 주제"];
    return {
      archetype: MAJOR_ARCHETYPES[card.id] ?? "큰 흐름을 보여주는 원형",
      symbols,
      imagery: card.imagery ?? `${symbols.slice(0, 3).join(", ")} 이미지가 핵심 단서입니다.`,
      numberTone: "메이저 아르카나는 일상의 작은 반응보다 큰 주제와 전환점을 봅니다.",
      suitTone: SUIT_TONES.메이저,
      relationshipTone: card.relationshipSymbolism ?? RELATIONSHIP_BY_SUIT.메이저,
    };
  }

  const rank = rankOf(card);
  const numberTone = NUMBER_TONES[rank] ?? "이 카드의 단계가 관계의 현재 성숙도를 보여줍니다.";
  return {
    archetype: `${suit}의 ${rank} 단계`,
    symbols: card.symbols ?? [suit, rank, "단계", "현실 장면"],
    imagery: card.imagery ?? `${suit}의 주제가 ${rank} 단계로 나타나는 장면입니다.`,
    numberTone,
    suitTone: SUIT_TONES[suit] ?? "카드의 슈트가 질문의 중심 영역을 보여줍니다.",
    relationshipTone: card.relationshipSymbolism ?? RELATIONSHIP_BY_SUIT[suit] ?? "관계에서 반복되는 반응 방식을 보여줍니다.",
  };
}
