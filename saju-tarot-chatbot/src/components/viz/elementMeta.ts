import type { FiveElementBalance } from "../../types";

/** 오행 시각화 공용 메타. SajuFactsPanel과 viz 컴포넌트가 같은 순서·라벨·풀이를 쓰도록 한 곳에 모은다. */
export const ELEMENT_ORDER: Array<keyof FiveElementBalance> = ["wood", "fire", "earth", "metal", "water"];

export const ELEMENT_LABEL: Record<keyof FiveElementBalance, string> = {
  wood: "목",
  fire: "화",
  earth: "토",
  metal: "금",
  water: "수",
};

export const ELEMENT_GLOSS: Record<keyof FiveElementBalance, string> = {
  wood: "성장·배움",
  fire: "표현·활력",
  earth: "안정·책임",
  metal: "판단·정리",
  water: "생각·휴식",
};

/** 한글 오행 글자(목화토금수) → 키. 작명·대운 등 한글 라벨 기반 데이터를 색상 클래스로 연결할 때 사용. */
export const ELEMENT_KEY_BY_KO: Record<string, keyof FiveElementBalance> = {
  목: "wood",
  화: "fire",
  토: "earth",
  금: "metal",
  수: "water",
};
