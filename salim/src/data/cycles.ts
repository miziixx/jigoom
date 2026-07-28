import type { CycleKey, CycleInfo } from "../types";

// 주기 옵션 (기획서 5장)
export const CYCLE: Record<CycleKey, CycleInfo> = {
  daily: { label: "매일", intervalDays: 1 },
  few_days: { label: "2~3일", intervalDays: 3 },
  weekly: { label: "매주", intervalDays: 7 },
  biweekly: { label: "격주", intervalDays: 14 },
  monthly: { label: "매월", intervalDays: 30 },
  quarterly: { label: "분기", intervalDays: 90 },
  yearly: { label: "연 1회", intervalDays: 365 },
};

export const CYCLE_KEYS: CycleKey[] = [
  "daily",
  "few_days",
  "weekly",
  "biweekly",
  "monthly",
  "quarterly",
  "yearly",
];

export const EFFORT_LABEL: Record<string, string> = {
  easy: "쉬움",
  normal: "보통",
  heavy: "힘듦",
};
