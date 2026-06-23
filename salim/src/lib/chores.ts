import type { Chore } from "../types";
import { CYCLE } from "../data/cycles";
import { daysBetween, parseDate, todayStr } from "./date";

// '할 차례' 판정 (기획서 5장 + 요일 지정 6-4)
export function isDue(chore: Chore, today: string = todayStr()): boolean {
  // 요일 지정 주기: 오늘 요일이 지정 요일이고 오늘 아직 안 했으면 노출
  if (chore.weekdays && chore.weekdays.length > 0) {
    const dow = parseDate(today).getDay();
    if (!chore.weekdays.includes(dow)) return false;
    return chore.lastDone !== today;
  }
  if (!chore.lastDone) return true;
  return daysBetween(chore.lastDone, today) >= CYCLE[chore.cycle].intervalDays;
}

// 며칠 밀렸는지 (음수면 아직 여유)
export function daysOverdue(chore: Chore, today: string = todayStr()): number {
  if (!chore.lastDone) return CYCLE[chore.cycle].intervalDays; // 한 번도 안 함
  return daysBetween(chore.lastDone, today) - CYCLE[chore.cycle].intervalDays;
}
