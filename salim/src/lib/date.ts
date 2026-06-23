// 날짜 유틸 — 모두 "YYYY-MM-DD" 문자열 기준.

export function todayStr(d: Date = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function parseDate(s: string): Date {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

// b - a (일 단위)
export function daysBetween(a: string, b: string): number {
  const ms = parseDate(b).getTime() - parseDate(a).getTime();
  return Math.round(ms / 86_400_000);
}

export function daysSince(s: string | null, today: string = todayStr()): number | null {
  if (!s) return null;
  return daysBetween(s, today);
}

export function addDays(s: string, n: number): string {
  const d = parseDate(s);
  d.setDate(d.getDate() + n);
  return todayStr(d);
}

export function currentMonth(): number {
  return new Date().getMonth() + 1;
}

// "6월 23일" 같은 짧은 표시
export function shortKor(s: string): string {
  const [, m, d] = s.split("-");
  return `${Number(m)}월 ${Number(d)}일`;
}
