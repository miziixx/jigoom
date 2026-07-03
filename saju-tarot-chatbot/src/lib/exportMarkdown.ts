import type { ReadingSession } from "../types";

const TYPE_LABEL: Record<ReadingSession["type"], string> = {
  saju: "사주 리딩",
  tarot: "타로 리딩",
  combo: "사주 + 타로 통합 리딩",
  today: "오늘의 흐름 리딩",
  flow: "월간·연간 운 흐름 리딩",
};

function formatBirthInfo(session: ReadingSession): string | null {
  const b = session.birthInfo;
  if (!b) return null;
  const calendar = b.calendarType === "solar" ? "양력" : "음력";
  const hour = b.hour === null ? "시간 모름" : `${b.hour}시${b.minute ? ` ${b.minute}분` : ""}`;
  const gender = b.gender === "female" ? "여성" : "남성";
  return `${calendar} ${b.year}년 ${b.month}월 ${b.day}일 ${hour} · ${gender}`;
}

function formatSajuChart(session: ReadingSession): string[] {
  const c = session.sajuChart;
  if (!c) return [];
  const lines = [
    `- 원국: 연주 ${c.year.ganZhi} · 월주 ${c.month.ganZhi} · 일주 ${c.day.ganZhi}${c.hour ? ` · 시주 ${c.hour.ganZhi}` : " · 시주 모름"}`,
    `- 오행: 목 ${c.fiveElements.wood} · 화 ${c.fiveElements.fire} · 토 ${c.fiveElements.earth} · 금 ${c.fiveElements.metal} · 수 ${c.fiveElements.water}`,
  ];
  if (c.strength) lines.push(`- 신강/신약(간이): ${c.strength.label}`);
  return lines;
}

function formatLuckCycles(session: ReadingSession): string[] {
  const l = session.luckCycles;
  if (!l) return [];
  return [
    `- 현재 대운: ${l.currentDaYun ?? "시작 전"} · 세운(${l.year}년): ${l.yearGanZhi} · 월운(${l.month}월): ${l.monthGanZhi}`,
  ];
}

/** 리딩 세션(계산된 사실 + AI 해석 + 후속 대화)을 사람이 읽기 좋은 마크다운 문서로 직렬화한다 */
export function buildReadingMarkdown(session: ReadingSession): string {
  const parts: string[] = [];
  parts.push(`# 인사이트 오라클 — ${TYPE_LABEL[session.type]}`);
  parts.push(`생성일: ${new Date(session.createdAt).toLocaleString("ko-KR")}`);
  if (session.question) parts.push(`질문: ${session.question}`);

  const birth = formatBirthInfo(session);
  const factLines = [...(birth ? [`- 생년월일시: ${birth}`] : []), ...formatSajuChart(session), ...formatLuckCycles(session)];
  if (session.tarotCards && session.tarotCards.length > 0) {
    factLines.push(
      `- 뽑힌 카드: ${session.tarotCards
        .map((t) => `${t.positionLabel ? `[${t.positionLabel}] ` : ""}${t.card.name} (${t.reversed ? "역방향" : "정방향"})`)
        .join(" · ")}`,
    );
  }
  if (factLines.length > 0) parts.push(["## 계산된 사실", ...factLines].join("\n"));

  const reply = session.messages.find((m) => m.role === "assistant")?.content ?? "";
  if (reply.trim()) parts.push(reply.trim());

  const followUps = session.messages.slice(2);
  if (followUps.length > 0) {
    const qa = followUps.map((m) => `**${m.role === "user" ? "Q" : "A"}.** ${m.content}`).join("\n\n");
    parts.push(["## 더 물어보기", qa].join("\n\n"));
  }

  parts.push("---\n이 리딩은 자기이해와 판단 보조용입니다. 의학·법률·투자·결혼·이직 등 중대한 결정의 근거로 사용하지 마세요.");

  return parts.join("\n\n");
}

/** 리딩 세션을 .md 파일로 다운로드한다 */
export function downloadReadingMarkdown(session: ReadingSession): void {
  const markdown = buildReadingMarkdown(session);
  const blob = new Blob([markdown], { type: "text/markdown;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `insight-oracle-${session.type}-${session.createdAt.slice(0, 10)}.md`;
  a.click();
  URL.revokeObjectURL(url);
}
