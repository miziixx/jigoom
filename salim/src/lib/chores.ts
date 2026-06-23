import type { Chore } from "../types";
import { CYCLE } from "../data/cycles";
import { daysBetween, todayStr } from "./date";

// '할 차례' 판정 (기획서 5장)
export function isDue(chore: Chore, today: string = todayStr()): boolean {
  if (!chore.lastDone) return true;
  return daysBetween(chore.lastDone, today) >= CYCLE[chore.cycle].intervalDays;
}

// 며칠 밀렸는지 (음수면 아직 여유)
export function daysOverdue(chore: Chore, today: string = todayStr()): number {
  if (!chore.lastDone) return CYCLE[chore.cycle].intervalDays; // 한 번도 안 함
  return daysBetween(chore.lastDone, today) - CYCLE[chore.cycle].intervalDays;
}
