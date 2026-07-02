export type ReadingType = "saju" | "tarot" | "combo";

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
  birthInfo?: BirthInfo;
  sajuChart?: SajuChart;
  tarotCards?: DrawnTarotCard[];
  messages: ChatMessage[];
}
