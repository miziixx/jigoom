import type { InventoryItem } from "../types";
import { addDays, daysBetween, todayStr } from "./date";

// 소비속도 예측 (기획서 11장)
// 구매 간격들의 평균 → 마지막 구매일 + 평균간격 = 예상 소진일
export function predictEmptyDate(item: InventoryItem): string | null {
  const dates = [...item.purchaseDates].sort();
  if (dates.length < 2) return null;
  const gaps: number[] = [];
  for (let i = 1; i < dates.length; i++) {
    gaps.push(daysBetween(dates[i - 1], dates[i]));
  }
  const avg = gaps.reduce((a, b) => a + b, 0) / gaps.length;
  if (avg <= 0) return null;
  const last = dates[dates.length - 1];
  return addDays(last, Math.round(avg));
}

export function avgGapDays(item: InventoryItem): number | null {
  const dates = [...item.purchaseDates].sort();
  if (dates.length < 2) return null;
  const gaps: number[] = [];
  for (let i = 1; i < dates.length; i++) {
    gaps.push(daysBetween(dates[i - 1], dates[i]));
  }
  return Math.round(gaps.reduce((a, b) => a + b, 0) / gaps.length);
}

// 곧 떨어질 예정인가 (예측일이 오늘로부터 3일 이내) 또는 이미 재고 부족
export function isRunningLow(item: InventoryItem, today: string = todayStr()): boolean {
  if (item.qty <= item.threshold) return true;
  const predicted = predictEmptyDate(item);
  if (!predicted) return false;
  return daysBetween(today, predicted) <= 3;
}
