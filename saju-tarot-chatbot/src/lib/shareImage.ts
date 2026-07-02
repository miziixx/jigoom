import type { ReadingSession } from "../types";

const TYPE_LABEL: Record<ReadingSession["type"], string> = {
  saju: "사주 리딩",
  tarot: "타로 리딩",
  combo: "사주 + 타로 통합 리딩",
};

const WIDTH = 1080;
const HEIGHT = 1350;

function wrapText(ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string[] {
  const lines: string[] = [];
  for (const paragraph of text.split("\n")) {
    let line = "";
    for (const char of paragraph) {
      if (ctx.measureText(line + char).width > maxWidth) {
        lines.push(line);
        line = char;
      } else {
        line += char;
      }
    }
    lines.push(line);
  }
  return lines;
}

/** 리딩의 핵심 요약을 담은 공유용 카드 이미지를 만들어 PNG로 다운로드한다 */
export function downloadShareImage(session: ReadingSession): void {
  const canvas = document.createElement("canvas");
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  // 배경
  const bg = ctx.createLinearGradient(0, 0, 0, HEIGHT);
  bg.addColorStop(0, "#1f1a30");
  bg.addColorStop(1, "#161221");
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  // 테두리
  ctx.strokeStyle = "#a970ff";
  ctx.lineWidth = 6;
  ctx.strokeRect(40, 40, WIDTH - 80, HEIGHT - 80);

  const left = 96;
  const contentWidth = WIDTH - left * 2;
  let y = 170;

  // 헤더
  ctx.fillStyle = "#c9a4ff";
  ctx.font = "bold 40px Pretendard, sans-serif";
  ctx.fillText("인사이트 오라클", left, y);
  y += 64;

  ctx.fillStyle = "#a89fc4";
  ctx.font = "32px Pretendard, sans-serif";
  ctx.fillText(`${TYPE_LABEL[session.type]} · ${new Date(session.createdAt).toLocaleDateString("ko-KR")}`, left, y);
  y += 80;

  // 계산된 사실 (사주 원국 / 카드)
  ctx.font = "30px Pretendard, sans-serif";
  ctx.fillStyle = "#ece8f7";
  if (session.sajuChart) {
    const c = session.sajuChart;
    const pillars = `${c.year.ganZhi}년 ${c.month.ganZhi}월 ${c.day.ganZhi}일${c.hour ? ` ${c.hour.ganZhi}시` : ""}`;
    ctx.fillText(`원국  ${pillars}`, left, y);
    y += 48;
  }
  if (session.luckCycles?.currentDaYun) {
    ctx.fillText(`현재 대운  ${session.luckCycles.currentDaYun} · 세운 ${session.luckCycles.yearGanZhi}`, left, y);
    y += 48;
  }
  if (session.tarotCards && session.tarotCards.length > 0) {
    const cards = session.tarotCards.map((t) => `${t.card.name.split(" (")[0]}${t.reversed ? "(역)" : ""}`).join(" · ");
    for (const line of wrapText(ctx, `카드  ${cards}`, contentWidth).slice(0, 2)) {
      ctx.fillText(line, left, y);
      y += 48;
    }
  }
  y += 24;

  // 질문
  if (session.question) {
    ctx.fillStyle = "#a89fc4";
    for (const line of wrapText(ctx, `Q. ${session.question}`, contentWidth).slice(0, 2)) {
      ctx.fillText(line, left, y);
      y += 48;
    }
    y += 24;
  }

  // 구분선
  ctx.strokeStyle = "#362f52";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(left, y);
  ctx.lineTo(WIDTH - left, y);
  ctx.stroke();
  y += 64;

  // 핵심 요약 (첫 assistant 응답의 첫 섹션)
  const reply = session.messages.find((m) => m.role === "assistant")?.content ?? "";
  const summaryMatch = reply.split(/^#\s+.+$/m).filter((s) => s.trim());
  const summary = (summaryMatch[0] ?? reply).trim();

  ctx.fillStyle = "#c9a4ff";
  ctx.font = "bold 34px Pretendard, sans-serif";
  ctx.fillText("핵심 요약", left, y);
  y += 56;

  ctx.fillStyle = "#ece8f7";
  ctx.font = "30px Pretendard, sans-serif";
  const maxSummaryLines = Math.floor((HEIGHT - 160 - y) / 48);
  for (const line of wrapText(ctx, summary, contentWidth).slice(0, maxSummaryLines)) {
    ctx.fillText(line, left, y);
    y += 48;
  }

  // 푸터 (해석의 한계 고지)
  ctx.fillStyle = "#a89fc4";
  ctx.font = "24px Pretendard, sans-serif";
  ctx.fillText("이 리딩은 자기이해와 판단 보조용입니다.", left, HEIGHT - 100);

  const a = document.createElement("a");
  a.href = canvas.toDataURL("image/png");
  a.download = `insight-oracle-${session.type}-${session.createdAt.slice(0, 10)}.png`;
  a.click();
}
