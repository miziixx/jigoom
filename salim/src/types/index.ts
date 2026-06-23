// 데이터 모델 (기획서 11장 코드화)

export type CycleKey =
  | "daily"
  | "few_days"
  | "weekly"
  | "biweekly"
  | "monthly"
  | "quarterly"
  | "yearly";

export type Effort = "easy" | "normal" | "heavy";
export type WeatherTag = "sunny" | "rainy" | "dusty";

export interface CycleInfo {
  label: string;
  intervalDays: number;
}

// 내장 마스터 집안일 (12장)
export interface ChoreTemplate {
  category: string;
  name: string;
  defaultCycle: CycleKey;
  durationMin: number;
  effort: Effort;
  weatherTag?: WeatherTag | null;
  seasonMonths?: number[];
  tip?: string;
  howtoId?: string;
}

// 내 집안일
export interface Chore {
  id: string;
  name: string;
  category: string;
  cycle: CycleKey;
  lastDone: string | null; // "YYYY-MM-DD"
  durationMin: number;
  effort: Effort;
  weatherTag?: WeatherTag | null;
  seasonMonths?: number[];
  tip?: string;
  howtoId?: string;
  custom?: boolean;
  weekdays?: number[]; // 요일 지정 주기 (0=일 ~ 6=토). 있으면 주기 대신 이 요일에 노출 (6-4)
}

export interface InventoryItem {
  id: string;
  name: string;
  qty: number;
  threshold: number;
  purchaseDates: string[]; // 구매 이력 → 소비속도/예측
  predictedEmptyDate?: string | null; // 계산값
}

export interface ShoppingItem {
  id: string;
  name: string;
  checked: boolean;
  fromInventoryId?: string;
  price?: number; // 구매 완료 시 가계부 지출로 합산 (5-3)
}

export interface Expense {
  id: string;
  date: string;
  amount: number;
  category: string;
  memo?: string;
}

export interface StashItem {
  id: string;
  name: string;
  location: string;
  lastTouched: string; // "YYYY-MM-DD"
}

export type LogType = "chore" | "purchase" | "expense" | "restock" | "declutter";

export interface LogEntry {
  id: string;
  date: string; // "YYYY-MM-DD"
  ts: number; // 정렬용 타임스탬프
  type: LogType;
  label: string;
  meta?: Record<string, unknown>;
}

export interface Settings {
  monthlyBudget?: number; // 월 예산 (6-4)
  weatherEnabled?: boolean; // 날씨 연동 켜기 (6-2)
}

// 살림백과 (16장) — 앱 내장 상수
export interface HowToEntry {
  id: string;
  category: string;
  title: string;
  summary?: string; // 목록에서 제목 아래 보여줄 한 줄 설명
  keywords: string[];
  cause?: string;
  steps: string[];
  prevent?: string[];
  caution?: string;
  emergency?: boolean;
  featured?: boolean; // 백과 첫 화면 '자주 찾는 항목'에 노출
  relatedChores?: string[];
}
