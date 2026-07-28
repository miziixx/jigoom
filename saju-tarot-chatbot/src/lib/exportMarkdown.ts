import type { ReadingSession } from "../types";
import type { FiveElementBalance, SajuChart } from "../types";
import { buildLifestyleGuide } from "./lifestyleGuide";

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
  const name = b.displayName ? `${b.displayName} · ` : "";
  return `${name}${calendar} ${b.year}년 ${b.month}월 ${b.day}일 ${hour} · ${gender}`;
}

function formatSajuChart(session: ReadingSession): string[] {
  const c = session.sajuChart;
  if (!c) return [];
  const lines = [
    `- 원국: 연주 ${c.year.ganZhi} · 월주 ${c.month.ganZhi} · 일주 ${c.day.ganZhi}${c.hour ? ` · 시주 ${c.hour.ganZhi}` : " · 시주 모름"}`,
    `- 오행: 목 ${c.fiveElements.wood} · 화 ${c.fiveElements.fire} · 토 ${c.fiveElements.earth} · 금 ${c.fiveElements.metal} · 수 ${c.fiveElements.water}`,
  ];
  if (c.strength) lines.push(`- 신강/신약(간이): ${c.strength.label}`);
  if (c.yinYang) lines.push(`- 음양: 양 ${c.yinYang.yang} · 음 ${c.yinYang.yin}`);
  if (c.yongshin) {
    lines.push(
      `- 보완/주의 기운 후보: 보완 ${((c.yongshin.yongshin ?? c.yongshin.supportive).join("·") || "없음")} · 과하면 부담 ${c.yongshin.unfavorable.join("·") || "없음"}`,
    );
  }
  const guide = buildLifestyleGuide(c, { todayGanZhi: session.luckCycles?.dayGanZhi });
  lines.push(
    `- 생활 처방: 기준 ${guide.basisLabel}${guide.secondaryLabel ? ` · 보조 ${guide.secondaryLabel}` : ""}${guide.avoidLabel ? ` · 과하면 부담 ${guide.avoidLabel}` : ""} · 색 ${guide.colors.join("·")} · 숫자 ${guide.numbers.join("·")} · 방향 ${guide.directions.join("·")}`,
  );
  if (guide.today) lines.push(`- 오늘 기운(일진 ${guide.today.label}): ${guide.today.headline}`);
  lines.push(`- 맞는 장소/자연: ${guide.places.join("·")} / ${guide.nature.join("·")}`);
  lines.push(`- 운동/회복: ${guide.movement.join("·")} / ${guide.recovery.join("·")}`);
  lines.push(`- 건강 체크 포인트: ${guide.healthFocus.join("·")}`);
  lines.push(`- 재미 미션: ${guide.playfulActions.join(" / ")}`);
  lines.push(`- 바로 실행 3개: ${guide.todayActions.join(" / ")}`);
  if (c.interactions) lines.push(`- 합충형파해: ${c.interactions.length > 0 ? c.interactions.join(", ") : "원국 내 해당 없음"}`);
  return lines;
}

function formatLuckCycles(session: ReadingSession): string[] {
  const l = session.luckCycles;
  if (!l) return [];
  const lines = [
    `- 현재 대운: ${l.currentDaYun ?? "시작 전"} · 세운(${l.year}년): ${l.yearGanZhi} · 월운(${l.month}월): ${l.monthGanZhi}`,
  ];
  if (l.monthlyFlow && l.monthlyFlow.length > 0) {
    lines.push("- 올해 1월~12월 월운:");
    lines.push(...l.monthlyFlow.map((m) => `  - ${m.month}월 ${m.ganZhi}: ${m.interactions.length > 0 ? m.interactions.join(", ") : "큰 상호작용 적음"}`));
  }
  return lines;
}

const ELEMENT_LABEL: Record<keyof FiveElementBalance, string> = {
  wood: "성장·시작·배움",
  fire: "표현·활력·추진력",
  earth: "안정·책임·현실감",
  metal: "판단·기준·결단",
  water: "생각·감정·휴식",
};

function topElement(chart: SajuChart): keyof FiveElementBalance | null {
  const entries = Object.entries(chart.fiveElements) as [keyof FiveElementBalance, number][];
  const top = entries.sort((a, b) => b[1] - a[1])[0];
  return top?.[1] > 0 ? top[0] : null;
}

function formatInsightExtras(session: ReadingSession): string[] {
  const lines: string[] = [];
  if (session.sajuChart) {
    const top = topElement(session.sajuChart);
    lines.push("## 내 반복 패턴 지도");
    if (top) lines.push(`- 두드러진 결: ${ELEMENT_LABEL[top]}`);
    if (session.sajuChart.strength) lines.push(`- 힘의 쓰임: ${session.sajuChart.strength.label}`);
    lines.push("- 읽는 법: 좋고 나쁨보다 반복되는 생활 패턴과 조정법을 확인하세요.");
  }
  if (session.luckCycles?.monthlyFlow && session.luckCycles.monthlyFlow.length > 0) {
    lines.push("## 월별 실행 캘린더");
    lines.push(
      ...session.luckCycles.monthlyFlow.map((m) => {
        const label = m.interactions.length >= 3 ? "조정 집중" : m.interactions.length >= 2 ? "변화 활용" : "기본기 정리";
        return `- ${m.month}월: ${label} · ${m.interactions.length > 0 ? m.interactions.join(", ") : "큰 상호작용 적음"}`;
      }),
    );
  }
  return lines;
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

  const insightExtras = formatInsightExtras(session);
  if (insightExtras.length > 0) parts.push(insightExtras.join("\n"));

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
