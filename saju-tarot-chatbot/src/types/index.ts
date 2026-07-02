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
  /** 0-59, 생략 시 0 */
  minute?: number;
  /** 출생지 키 (진태양시 보정용). "none"이면 보정 안 함 */
  birthPlace?: string;
  gender: Gender;
}

export interface TimeCorrection {
  /** 적용된 보정 설명 (예: "서울 경도 보정 -32분, 서머타임 -60분") */
  applied: string[];
  /** 보정 후 시각 (예: "1988-07-15 13:28") */
  correctedDateTime: string;
  /** 시주 경계(홀수시) 근처 출생 경고 */
  boundaryWarning: string | null;
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

export interface StrengthAssessment {
  /** 일간을 돕는 세력 점수 (비겁+인성) */
  supportScore: number;
  /** 전체 점수 */
  totalScore: number;
  label: "신강" | "중화" | "신약";
  /** 득령(월지가 일간을 돕는지) 여부 등 판정 근거 */
  detail: string;
}

export interface YongshinCandidates {
  /** 용신/희신 후보 오행 */
  supportive: string[];
  /** 기신 후보 오행 */
  unfavorable: string[];
  /** 판정 방법과 한계 설명 */
  note: string;
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
  /** 이하 심화 계산 (구버전 저장 데이터에는 없을 수 있음) */
  yinYang?: { yang: number; yin: number };
  /** 기둥별 지장간 (예: "월지 자: 임·계") */
  hiddenStems?: string[];
  /** 지지 십성 (지장간 정기 기준) */
  branchTenGods?: string[];
  /** 합충형파해 목록 (예: "월지-연지 자오충") */
  interactions?: string[];
  strength?: StrengthAssessment;
  yongshin?: YongshinCandidates;
  /** 12운성 (일간 기준 기둥별) */
  twelveStages?: string[];
  /** 공망 (일주 순중공망 지지 2개) */
  gongmang?: string;
  /** 조후(계절) 관점 노트 */
  seasonNote?: string;
  /** 진태양시/서머타임 보정 내역 */
  timeCorrection?: TimeCorrection;
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
  /** 오늘 일진 간지 */
  dayGanZhi?: string;
  year: number;
  month: number;
  /** 현재 대운/세운/월운/일진이 원국과 맺는 합충형파해 */
  luckInteractions?: string[];
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
