import type { FiveElementBalance, SajuChart } from "../types";

export type LifestyleGuide = {
  basisElement: keyof FiveElementBalance;
  basisLabel: string;
  basisReason: string;
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
  evidence: string[];
};

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

const ELEMENT_LIFESTYLE: Record<
  keyof FiveElementBalance,
  Omit<LifestyleGuide, "basisElement" | "basisLabel" | "basisReason" | "evidence">
> = {
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

function primarySupportElement(chart: SajuChart): keyof FiveElementBalance | null {
  const yongshin = chart.yongshin?.yongshin?.[0] ?? chart.yongshin?.supportive?.[0];
  return yongshin ? (KO_TO_ELEMENT[yongshin] ?? null) : null;
}

function weakestElement(chart: SajuChart): keyof FiveElementBalance {
  return (Object.keys(chart.fiveElements) as Array<keyof FiveElementBalance>).reduce((weakest, key) =>
    chart.fiveElements[key] < chart.fiveElements[weakest] ? key : weakest,
  );
}

export function buildLifestyleGuide(chart: SajuChart): LifestyleGuide {
  const support = primarySupportElement(chart);
  const basisElement = support ?? weakestElement(chart);
  const basisLabel = ELEMENT_KO[basisElement];
  const source = ELEMENT_LIFESTYLE[basisElement];
  const yong = chart.yongshin?.yongshin ?? chart.yongshin?.supportive ?? [];
  const hee = chart.yongshin?.heesin ?? [];
  const unfavorable = chart.yongshin?.unfavorable ?? [];

  return {
    basisElement,
    basisLabel,
    basisReason: support
      ? `${basisLabel} 계열은 이 사주에서 보완하면 좋은 흐름으로 계산됩니다.`
      : `${basisLabel} 계열이 상대적으로 약해 생활에서 의식적으로 채우기 좋은 흐름입니다.`,
    ...source,
    evidence: [
      `오행 분포: 목 ${chart.fiveElements.wood} · 화 ${chart.fiveElements.fire} · 토 ${chart.fiveElements.earth} · 금 ${chart.fiveElements.metal} · 수 ${chart.fiveElements.water}`,
      yong.length > 0 ? `용신 후보: ${yong.join("·")}` : "",
      hee.length > 0 ? `희신 후보: ${hee.join("·")}` : "",
      unfavorable.length > 0 ? `기신 후보: ${unfavorable.join("·")}` : "",
      chart.strength ? `신강/신약: ${chart.strength.label}` : "",
    ].filter(Boolean),
  };
}
