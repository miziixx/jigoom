export type ReadingType = "saju" | "tarot" | "combo";

/** 해석 포커스: 전반 / 직업·돈 / 연애·관계 / 건강·컨디션 */
export type ReadingFocus = "general" | "career" | "relationship" | "wellness";

export type CalendarType = "solar" | "lunar";

export type Gender = "female" | "male";

export interface BirthInfo {
  calendarType: CalendarType;
  year: number;
  month: number;
  day: number;
  /** 0-23, 시간을 모르면 null */
  hour: number | null;
  gender: Gender;
}

export interface FiveElementBalance {
  wood: number;
  fire: number;
  earth: number;
  metal: number;
  water: number;
}

export interface SajuPillar {
  gan: string;
  zhi: string;
  ganZhi: string;
}

export interface SajuChart {
  year: SajuPillar;
  month: SajuPillar;
  day: SajuPillar;
  /** 출생 시간을 모르면 null */
  hour: SajuPillar | null;
  fiveElements: FiveElementBalance;
  tenGods: string[];
  dayMasterGan: string;
}

export interface DaYunInfo {
  startAge: number;
  endAge: number;
  startYear: number;
  endYear: number;
  ganZhi: string;
  current: boolean;
}

export interface LuckCycles {
  daYun: DaYunInfo[];
  /** 현재 대운 간지 (아직 대운 시작 전이면 null) */
  currentDaYun: string | null;
  /** 올해 세운 간지 */
  yearGanZhi: string;
  /** 이번 달 월운 간지 (절기 기준 월주) */
  monthGanZhi: string;
  year: number;
  month: number;
}

export type TarotArcana = "major" | "minor";

export interface TarotCardDefinition {
  id: number;
  name: string;
  arcana: TarotArcana;
  uprightMeaning: string;
  reversedMeaning: string;
}

export interface DrawnTarotCard {
  card: TarotCardDefinition;
  reversed: boolean;
  position: number;
  /** 스프레드에서 이 자리의 의미 (예: "과거/원인", "장애물") */
  positionLabel?: string;
}

export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

export interface ReadingSession {
  id: string;
  type: ReadingType;
  createdAt: string;
  question: string;
  favorite?: boolean;
  focus?: ReadingFocus;
  birthInfo?: BirthInfo;
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  tarotCards?: DrawnTarotCard[];
  messages: ChatMessage[];
}
