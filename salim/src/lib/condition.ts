import type { Chore } from "../types";
import { CYCLE } from "../data/cycles";
import { daysSince, todayStr } from "./date";

// 집 컨디션 게이지 계산 (기획서 6장)

export function choreHealth(chore: Chore, today: string = todayStr()): number {
  const interval = CYCLE[chore.cycle].intervalDays;
  if (chore.lastDone == null) return 40; // 한 번도 안 함
  const since = daysSince(chore.lastDone, today) ?? 0;
  const daysOver = Math.max(0, since - interval);
  return 100 - Math.min(100, (daysOver / interval) * 50); // 1주기 밀리면 -50, 2주기면 0
}

export function houseScore(chores: Chore[], today: string = todayStr()): number {
  if (chores.length === 0) return 100;
  const sum = chores.reduce((acc, c) => acc + choreHealth(c, today), 0);
  return Math.round(sum / chores.length);
}

export interface ConditionLevel {
  level: 0 | 1 | 2 | 3; // 0 최악 ~ 3 최상
  label: string;
  comment: string;
}

export function conditionLevel(score: number): ConditionLevel {
  if (score >= 90) return { level: 3, label: "쾌적해요", comment: "집이 반짝여요 ✨" };
  if (score >= 70) return { level: 2, label: "양호해요", comment: "잘 돌보고 있어요" };
  if (score >= 50) return { level: 1, label: "슬슬 챙길 때", comment: "몇 가지 밀렸어요" };
  return { level: 0, label: "손길이 필요해요", comment: "오늘 하나만 해볼까요?" };
}
