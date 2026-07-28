import type { Expense, LogEntry } from "../types";
import { addDays, todayStr } from "./date";

export function monthKey(date: string): string {
  return date.slice(0, 7); // "YYYY-MM"
}

export function monthExpenses(
  expenses: Expense[],
  month: string = todayStr().slice(0, 7),
): Expense[] {
  return expenses.filter((e) => e.date.startsWith(month));
}

export function sumAmount(list: Expense[]): number {
  return list.reduce((a, b) => a + b.amount, 0);
}

export function byCategory(list: Expense[]): { category: string; amount: number }[] {
  const map = new Map<string, number>();
  for (const e of list) map.set(e.category, (map.get(e.category) ?? 0) + e.amount);
  return Array.from(map.entries())
    .map(([category, amount]) => ({ category, amount }))
    .sort((a, b) => b.amount - a.amount);
}

// 최근 N일 동안 완료한 집안일 수 (6-3)
export function choresDoneInDays(logs: LogEntry[], days: number): number {
  const since = addDays(todayStr(), -(days - 1));
  return logs.filter((l) => l.type === "chore" && l.date >= since).length;
}

export function countByType(logs: LogEntry[], type: LogEntry["type"], sinceDays: number): number {
  const since = addDays(todayStr(), -(sinceDays - 1));
  return logs.filter((l) => l.type === type && l.date >= since).length;
}

// 오늘(또는 어제)부터 거꾸로, 집안일을 한 연속 일수 (6-3)
export function streakDays(logs: LogEntry[]): number {
  const done = new Set(logs.filter((l) => l.type === "chore").map((l) => l.date));
  let cur = todayStr();
  if (!done.has(cur)) cur = addDays(cur, -1); // 오늘 아직 안 했어도 어제까지 연속이면 유지
  let streak = 0;
  while (done.has(cur)) {
    streak++;
    cur = addDays(cur, -1);
  }
  return streak;
}
