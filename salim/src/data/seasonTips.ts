// 계절(오프라인) 제안 규칙 — 현재 月 기반 (기획서 8장).
// chore: 내 집안일에 같은 이름이 있으면 '오늘 할 일'로 끌어올릴 수 있음.

export interface SeasonTip {
  text: string;
  chore?: string;
}

const RULES: Record<number, SeasonTip[]> = {
  1: [{ text: "한겨울, 보일러·난방 점검하기 좋아요.", chore: "보일러 점검" }],
  2: [{ text: "환절기 전 환기와 침구 관리를 챙겨요.", chore: "환기(창문 열기)" }],
  3: [
    { text: "환절기예요. 필터 교체·환기를 챙겨요.", chore: "공기청정기 필터 점검" },
    { text: "봄맞이 커튼 세탁 어때요?", chore: "커튼 세탁" },
  ],
  4: [{ text: "미세먼지 많은 철, 공기청정기 필터를 점검해요.", chore: "공기청정기 필터 점검" }],
  5: [{ text: "더워지기 전 에어컨 필터를 청소해요.", chore: "에어컨 필터 청소" }],
  6: [
    { text: "장마 전 곰팡이 점검·제거를 미리 해두면 좋아요.", chore: "곰팡이 점검·제거" },
    { text: "습한 철, 세탁조 통세척을 챙겨요.", chore: "세탁조 통세척" },
  ],
  7: [{ text: "곰팡이가 잘 피는 철이에요. 욕실 곰팡이를 점검해요.", chore: "곰팡이 점검·제거" }],
  8: [{ text: "습기 관리가 중요한 철, 환기를 자주 해요.", chore: "환기(창문 열기)" }],
  9: [
    { text: "환절기 옷장 정리·계절 옷 교체 어때요?", chore: "옷장 계절 옷 교체" },
    { text: "가을, 이불 세탁하기 좋은 철이에요.", chore: "이불 세탁" },
  ],
  10: [{ text: "추워지기 전 보일러를 점검해요.", chore: "보일러 점검" }],
  11: [{ text: "겨울 대비 보일러 점검·창틀 단속을 챙겨요.", chore: "보일러 점검" }],
  12: [{ text: "연말 대청소로 한 해를 정리해볼까요?", chore: "집 전체 대청소" }],
};

export function seasonTips(month = new Date().getMonth() + 1): SeasonTip[] {
  return RULES[month] ?? [];
}
