import type { FiveElementBalance, SajuChart } from "../types/index.js";

// 천간/지지 → 오행 (한글). saju.ts에도 같은 표가 있지만, 여기서 saju.ts를 import하면
// 무거운 lunar-javascript까지 이 모듈 그래프(및 서버리스 API 번들)에 딸려 들어오므로,
// 계산이 아닌 이 작은 상수 표는 독립적으로 둔다.
const GAN_WUXING: Record<string, keyof FiveElementBalance> = {
  갑: "wood", 을: "wood",
  병: "fire", 정: "fire",
  무: "earth", 기: "earth",
  경: "metal", 신: "metal",
  임: "water", 계: "water",
};
const ZHI_WUXING: Record<string, keyof FiveElementBalance> = {
  자: "water", 축: "earth", 인: "wood", 묘: "wood", 진: "earth", 사: "fire",
  오: "fire", 미: "earth", 신: "metal", 유: "metal", 술: "earth", 해: "water",
};

export type Element = keyof FiveElementBalance;

/** 오늘 일진 기운이 내 보완 기운과 맺는 관계 */
export type TodayEnergy = {
  element: Element;
  label: string;
  /** boost: 오늘 기운이 내 필요 기운을 살려줌 / temper: 과해지기 쉬운 기운이 들어옴 / steady: 무난 */
  relation: "boost" | "temper" | "steady";
  headline: string;
  note: string;
  action: string;
};

export type LifestyleGuide = {
  basisElement: Element;
  basisLabel: string;
  basisReason: string;
  /** 보조로 함께 채우면 좋은 기운 (희신 또는 두 번째로 약한 오행) */
  secondaryElement: Element | null;
  secondaryLabel: string | null;
  /** 과해지면 부담이 되는 기운 (기신) */
  avoidElement: Element | null;
  avoidLabel: string | null;
  colors: string[];
  numbers: number[];
  directions: string[];
  places: string[];
  nature: string[];
  movement: string[];
  workStyle: string[];
  recovery: string[];
  healthFocus: string[];
  playfulActions: string[];
  todayActions: string[];
  caution: string;
  /** 오늘 일진 기운을 전달하면 계산되는, 날짜마다 달라지는 오늘 전용 흐름 */
  today: TodayEnergy | null;
  evidence: string[];
};

export interface LifestyleOptions {
  /** 오늘 일진 간지 (예: "갑자"). 주면 today 필드가 채워진다. */
  todayGanZhi?: string;
}

const ELEMENT_KO: Record<keyof FiveElementBalance, string> = {
  wood: "목",
  fire: "화",
  earth: "토",
  metal: "금",
  water: "수",
};

const KO_TO_ELEMENT: Record<string, keyof FiveElementBalance> = {
  목: "wood",
  화: "fire",
  토: "earth",
  금: "metal",
  수: "water",
};

type ElementLifestyle = Pick<
  LifestyleGuide,
  | "colors"
  | "numbers"
  | "directions"
  | "places"
  | "nature"
  | "movement"
  | "workStyle"
  | "recovery"
  | "healthFocus"
  | "playfulActions"
  | "todayActions"
  | "caution"
>;

const ELEMENT_LIFESTYLE: Record<keyof FiveElementBalance, ElementLifestyle> = {
  wood: {
    colors: ["초록", "청록", "맑은 하늘색"],
    numbers: [3, 8],
    directions: ["동쪽", "해가 드는 창가", "나무가 보이는 자리"],
    places: ["공원", "식물 많은 카페", "도서관", "새로운 동네"],
    nature: ["숲", "가로수길", "완만한 언덕"],
    movement: ["가벼운 조깅", "스트레칭", "등산 초입 걷기", "새로운 동작을 배우는 운동"],
    workStyle: ["새 계획 세우기", "배움·기획·성장 목표 정리", "아침에 첫 행동을 작게 시작하기"],
    recovery: ["햇빛 보며 걷기", "식물 돌보기", "배운 것을 기록하기"],
    healthFocus: ["목·어깨 긴장", "눈 피로", "간 피로감", "수면 리듬"],
    playfulActions: ["휴대폰 배경을 숲이나 가로수길 사진으로 바꾸기", "책상 위에 작은 식물 하나 두기", "아침 첫 일정에 10분 산책 넣기"],
    todayActions: ["오늘 할 일을 3개만 적고 첫 번째만 바로 시작하기", "점심 뒤 10분 동안 햇빛 보며 걷기", "자기 전 목·어깨 스트레칭 5분 하기"],
    caution: "시작만 늘리고 마무리를 놓치지 않도록, 계획은 작게 쪼개는 편이 좋습니다.",
  },
  fire: {
    colors: ["빨강", "분홍", "코랄", "따뜻한 주황"],
    numbers: [2, 7],
    directions: ["남쪽", "밝은 조명 아래", "사람이 모이는 공간"],
    places: ["공연장", "운동 스튜디오", "활기 있는 거리", "햇빛 좋은 카페"],
    nature: ["햇볕", "불빛", "탁 트인 광장"],
    movement: ["댄스", "인터벌 걷기", "가벼운 근력 운동", "땀이 살짝 나는 운동"],
    workStyle: ["발표·공유·홍보", "아이디어를 밖으로 꺼내기", "미루던 연락 먼저 하기"],
    recovery: ["따뜻한 샤워", "짧은 햇빛 산책", "좋아하는 음악 듣기"],
    healthFocus: ["심장 두근거림", "열감", "눈 피로", "수면 과흥분"],
    playfulActions: ["잠금화면을 노을이나 조명 사진으로 바꾸기", "오늘 입는 옷이나 소품에 따뜻한 색 하나 넣기", "좋아하는 노래 1곡 틀고 몸 풀기"],
    todayActions: ["오전이나 낮에 햇빛 10분 보기", "미루던 연락 1개만 먼저 보내기", "잠들기 1시간 전 화면 밝기 낮추기"],
    caution: "속도가 빨라질수록 말과 결정을 한 박자 늦추면 실수가 줄어듭니다.",
  },
  earth: {
    colors: ["노랑", "베이지", "크림", "따뜻한 갈색"],
    numbers: [5, 10],
    directions: ["중앙", "집 근처", "익숙하고 안정적인 자리"],
    places: ["집", "동네 카페", "정리된 작업실", "흙길이 있는 산책로"],
    nature: ["들판", "흙길", "낮은 산", "마당"],
    movement: ["필라테스", "코어 운동", "느린 산책", "요가"],
    workStyle: ["일정표 만들기", "재정 정리", "집중할 환경 고정", "반복 루틴 만들기"],
    recovery: ["공간 정리", "따뜻한 식사", "수면 시간 고정"],
    healthFocus: ["소화", "복부 긴장", "체중 리듬", "허리·골반"],
    playfulActions: ["배경화면을 들판이나 따뜻한 방 사진으로 바꾸기", "지갑이나 메모앱에 이번 달 고정비를 적어두기", "침대 옆이나 책상 위 한 구역만 비우기"],
    todayActions: ["저녁 식사 시간을 30분만 앞당기기", "책상 위 물건 10개만 정리하기", "이번 주 돈 나갈 곳 3개를 메모하기"],
    caution: "책임을 너무 많이 떠안기 쉬우니, 내 몫과 남의 몫을 나누는 기준이 필요합니다.",
  },
  metal: {
    colors: ["흰색", "은색", "회색", "차분한 네이비"],
    numbers: [4, 9],
    directions: ["서쪽", "정돈된 책상", "시야가 깔끔한 자리"],
    places: ["전시관", "깔끔한 업무 공간", "조용한 카페", "문구점"],
    nature: ["바위", "능선", "맑은 공기", "가을 숲"],
    movement: ["웨이트 트레이닝", "자세 교정", "호흡을 맞춘 걷기", "규칙 있는 운동"],
    workStyle: ["기준 세우기", "불필요한 것 줄이기", "계약·문서·돈 흐름 점검", "결정 목록 만들기"],
    recovery: ["책상 정리", "할 일 덜어내기", "깊은 호흡"],
    healthFocus: ["호흡", "피부·건조함", "치아·턱 긴장", "어깨 결림"],
    playfulActions: ["배경화면을 미니멀한 흰색/은색 이미지로 바꾸기", "오늘 안 쓰는 앱 3개를 지우기", "책상 위에 흰색·은색 소품 하나만 남기기"],
    todayActions: ["결정해야 할 일을 종이에 2분류로 나누기", "불필요한 알림 3개 끄기", "깊게 숨을 내쉬는 호흡 10번 하기"],
    caution: "기준이 강해질수록 스스로와 타인에게 날카로워질 수 있어, 말투를 부드럽게 조정하는 편이 좋습니다.",
  },
  water: {
    colors: ["검정", "남색", "짙은 파랑", "차분한 보라"],
    numbers: [1, 6],
    directions: ["북쪽", "조용한 구석 자리", "물 가까운 방향"],
    places: ["강가", "바닷가", "호수", "조용한 독서 공간"],
    nature: ["강", "바다", "비 오는 길", "물소리가 있는 곳"],
    movement: ["수영", "천천히 걷기", "호흡 명상", "무리 없는 유산소"],
    workStyle: ["생각 정리", "자료 조사", "혼자 집중하는 시간 확보", "감정 기록"],
    recovery: ["충분한 수면", "물가 산책", "휴대폰 알림 줄이기"],
    healthFocus: ["신장·방광 컨디션", "하체 순환", "수면", "귀·머리 피로"],
    playfulActions: ["휴대폰 배경을 바다·강·호수 사진으로 바꾸기", "책상에 투명한 물컵을 두고 자주 보이게 하기", "퇴근길에 물가나 조용한 길로 10분 돌아가기"],
    todayActions: ["물 한 컵을 먼저 마시고 일을 시작하기", "잠들기 전 생각나는 걱정 3개를 메모장에 내려놓기", "느린 걸음으로 15분 걷기"],
    caution: "생각이 깊어질수록 실행이 늦어질 수 있으니, 고민 시간을 정해두고 작은 행동으로 옮기는 편이 좋습니다.",
  },
};

// 오행 상생: 목→화→토→금→수→목 / 상극: 목→토, 토→수, 수→화, 화→금, 금→목
const GENERATES: Record<Element, Element> = { wood: "fire", fire: "earth", earth: "metal", metal: "water", water: "wood" };
const OVERCOMES: Record<Element, Element> = { wood: "earth", earth: "water", water: "fire", fire: "metal", metal: "wood" };

function primarySupportElement(chart: SajuChart): Element | null {
  const yongshin = chart.yongshin?.yongshin?.[0] ?? chart.yongshin?.supportive?.[0];
  return yongshin ? (KO_TO_ELEMENT[yongshin] ?? null) : null;
}

function sortedByScarcity(chart: SajuChart): Element[] {
  return (Object.keys(chart.fiveElements) as Element[]).slice().sort((a, b) => chart.fiveElements[a] - chart.fiveElements[b]);
}

/** 보조 기운: 희신 첫 후보(기준과 다르면) → 없으면 두 번째로 약한 오행 */
function secondarySupportElement(chart: SajuChart, basis: Element): Element | null {
  const hee = chart.yongshin?.heesin?.[0];
  const heeEl = hee ? KO_TO_ELEMENT[hee] : undefined;
  if (heeEl && heeEl !== basis) return heeEl;
  const scarce = sortedByScarcity(chart).filter((el) => el !== basis);
  return scarce[0] ?? null;
}

function avoidElement(chart: SajuChart): Element | null {
  const un = chart.yongshin?.unfavorable?.[0];
  return un ? (KO_TO_ELEMENT[un] ?? null) : null;
}

/** 일진 간지에서 오늘의 대표 기운(천간 오행)을 뽑는다. */
function todayElementOf(todayGanZhi: string): Element | null {
  const gan = todayGanZhi?.[0];
  if (gan && GAN_WUXING[gan]) return GAN_WUXING[gan];
  const zhi = todayGanZhi?.[1];
  return zhi && ZHI_WUXING[zhi] ? ZHI_WUXING[zhi] : null;
}

function buildToday(basis: Element, avoid: Element | null, todayGanZhi?: string): TodayEnergy | null {
  if (!todayGanZhi) return null;
  const element = todayElementOf(todayGanZhi);
  if (!element) return null;
  const label = ELEMENT_KO[element];
  const basisLabel = ELEMENT_KO[basis];

  // 오늘 기운이 내 보완 기운(basis)을 살려주는가(같거나 상생), 누르는가(상극/기신), 무난한가
  const boosts = element === basis || GENERATES[element] === basis;
  const tempers = (avoid && element === avoid) || OVERCOMES[element] === basis;

  if (boosts) {
    return {
      element,
      label,
      relation: "boost",
      headline: `오늘은 ${label} 기운이 들어와, 채우고 싶던 ${basisLabel} 흐름이 자연스럽게 살아나는 날`,
      note: `평소보다 ${basisLabel}에 맞는 행동이 수월하게 붙습니다. 미뤄둔 걸 오늘 한 걸음 밀어보기 좋아요.`,
      action: ELEMENT_LIFESTYLE[basis].todayActions[0],
    };
  }
  if (tempers) {
    return {
      element,
      label,
      relation: "temper",
      headline: `오늘은 ${label} 기운이 강하게 들어와, 한쪽으로 쏠리거나 지치기 쉬운 날`,
      note: `무리해서 밀어붙이기보다, ${basisLabel} 흐름으로 균형을 잡아주면 소모가 줄어듭니다.`,
      action: ELEMENT_LIFESTYLE[basis].recovery[0] ? `${ELEMENT_LIFESTYLE[basis].recovery[0]}로 한 박자 쉬어가기` : ELEMENT_LIFESTYLE[basis].todayActions[0],
    };
  }
  return {
    element,
    label,
    relation: "steady",
    headline: `오늘은 ${label} 기운이 무난하게 흐르는, 크게 흔들리지 않는 날`,
    note: `특별한 변수보다, 평소 ${basisLabel} 루틴을 꾸준히 지키기 좋은 날입니다.`,
    action: ELEMENT_LIFESTYLE[basis].todayActions[0],
  };
}

export function buildLifestyleGuide(chart: SajuChart, options: LifestyleOptions = {}): LifestyleGuide {
  const support = primarySupportElement(chart);
  const basisElement = support ?? sortedByScarcity(chart)[0];
  const basisLabel = ELEMENT_KO[basisElement];
  const source = ELEMENT_LIFESTYLE[basisElement];
  const secondaryElement = secondarySupportElement(chart, basisElement);
  const secondaryLabel = secondaryElement ? ELEMENT_KO[secondaryElement] : null;
  const avoid = avoidElement(chart);
  const avoidLabel = avoid ? ELEMENT_KO[avoid] : null;
  const strengthLabel = chart.strength?.label;

  const yong = chart.yongshin?.yongshin ?? chart.yongshin?.supportive ?? [];
  const hee = chart.yongshin?.heesin ?? [];
  const unfavorable = chart.yongshin?.unfavorable ?? [];

  // 보조 기운의 대표 항목을 섞어, 같은 기준 기운이라도 사람마다 조금씩 달라지게 한다.
  const secondary = secondaryElement ? ELEMENT_LIFESTYLE[secondaryElement] : null;
  const colors = secondary ? [...source.colors.slice(0, 2), secondary.colors[0]] : source.colors;
  const places = secondary ? [...source.places.slice(0, 2), secondary.places[0]] : source.places;
  const movement = secondary ? [...source.movement.slice(0, 2), secondary.movement[0]] : source.movement;

  const strengthNote = strengthLabel
    ? strengthLabel.includes("신강")
      ? " 기운이 강한 편이라, 채우기보다 덜어내고 흘려보내는 쪽이 균형에 맞습니다."
      : strengthLabel.includes("신약")
        ? " 기운이 약한 편이라, 무리하지 않게 아껴 쓰며 채우는 리듬이 좋습니다."
        : ""
    : "";

  const caution = avoidLabel
    ? `${source.caution} 특히 ${avoidLabel} 기운이 과해질 때(예: 한쪽으로만 쏠릴 때) 부담이 커지니, 그럴 땐 ${basisLabel}·${secondaryLabel ?? basisLabel} 쪽으로 균형을 잡으세요.`
    : source.caution;

  const basisReason =
    (support
      ? `${basisLabel} 계열은 이 사주에서 보완하면 좋은 흐름으로 계산됩니다.`
      : `${basisLabel} 계열이 상대적으로 약해 생활에서 의식적으로 채우기 좋은 흐름입니다.`) +
    (secondaryLabel ? ` 여기에 ${secondaryLabel} 기운을 곁들이면 균형이 더 맞습니다.` : "") +
    strengthNote;

  return {
    basisElement,
    basisLabel,
    basisReason,
    secondaryElement,
    secondaryLabel,
    avoidElement: avoid,
    avoidLabel,
    ...source,
    colors,
    places,
    movement,
    caution,
    today: buildToday(basisElement, avoid, options.todayGanZhi),
    evidence: [
      `오행 분포: 목 ${chart.fiveElements.wood} · 화 ${chart.fiveElements.fire} · 토 ${chart.fiveElements.earth} · 금 ${chart.fiveElements.metal} · 수 ${chart.fiveElements.water}`,
      yong.length > 0 ? `용신 후보: ${yong.join("·")}` : "",
      hee.length > 0 ? `희신 후보: ${hee.join("·")}` : "",
      unfavorable.length > 0 ? `기신 후보: ${unfavorable.join("·")}` : "",
      strengthLabel ? `신강/신약: ${strengthLabel}` : "",
    ].filter(Boolean),
  };
}
