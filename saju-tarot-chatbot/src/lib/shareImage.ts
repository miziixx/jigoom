import type { ReadingSession } from "../types";

const TYPE_LABEL: Record<ReadingSession["type"], string> = {
  saju: "사주 리딩",
  tarot: "타로 리딩",
  combo: "사주 + 타로 통합 리딩",
  today: "오늘의 흐름 리딩",
  flow: "월간·연간 운 흐름 리딩",
};

const WIDTH = 1080;
const HEIGHT = 1350;
const LEFT = 92;
const CONTENT_WIDTH = WIDTH - LEFT * 2;
const BODY_TOP = 350;
const BODY_BOTTOM = HEIGHT - 132;
const LINE_HEIGHT = 44;
const MAX_BODY_LINES = Math.floor((BODY_BOTTOM - BODY_TOP) / LINE_HEIGHT);

interface ShareSection {
  title: string;
  body: string;
}

interface SharePage {
  title: string;
  lines: string[];
  part: number;
  totalParts: number;
}

/** shareGoosebumpImage.ts(C-2 공유 카드)에서도 재사용하는 캔버스 줄바꿈 유틸. */
export function wrapText(ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string[] {
  const lines: string[] = [];
  for (const paragraph of text.split("\n")) {
    const trimmed = paragraph.trimEnd();
    if (!trimmed) {
      lines.push("");
      continue;
    }

    let line = "";
    for (const char of trimmed) {
      if (ctx.measureText(line + char).width > maxWidth && line) {
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

function stripMarkdown(text: string): string {
  return text
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/__(.+?)__/g, "$1")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/^\s*>\s?/gm, "")
    .replace(/^\s*[-*+]\s+/gm, "• ")
    .replace(/^\[([^\]]+)\]\s*$/gm, "$1")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function parseSections(reply: string): ShareSection[] {
  const parts = reply.split(/^#\s+(.+)$/m).slice(1);
  const sections: ShareSection[] = [];
  for (let i = 0; i < parts.length; i += 2) {
    sections.push({ title: parts[i].trim(), body: stripMarkdown(parts[i + 1] ?? "") });
  }
  return sections.length > 0 ? sections : [{ title: "리딩 결과", body: stripMarkdown(reply) }];
}

function buildFactsSection(session: ReadingSession): ShareSection {
  const lines = [`리딩 종류: ${TYPE_LABEL[session.type]}`, `생성일: ${new Date(session.createdAt).toLocaleDateString("ko-KR")}`];

  if (session.birthInfo?.displayName) lines.push(`이름: ${session.birthInfo.displayName}`);
  if (session.question) lines.push(`질문: ${session.question}`);
  if (session.sajuChart) {
    const c = session.sajuChart;
    const pillars = `${c.year.ganZhi}년 ${c.month.ganZhi}월 ${c.day.ganZhi}일${c.hour ? ` ${c.hour.ganZhi}시` : ""}`;
    lines.push(`원국: ${pillars}`);
  }
  if (session.luckCycles?.currentDaYun) {
    lines.push(`현재 큰 흐름: ${session.luckCycles.currentDaYun}`);
    lines.push(`올해 흐름: ${session.luckCycles.yearGanZhi}`);
  }
  if (session.luckCycles?.monthlyFlow && session.luckCycles.monthlyFlow.length > 0) {
    lines.push(`월별 흐름: ${session.luckCycles.monthlyFlow.map((m) => `${m.month}월 ${m.ganZhi}`).join(" · ")}`);
  }
  if (session.tarotCards && session.tarotCards.length > 0) {
    const cards = session.tarotCards.map((t) => `${t.card.name.split(" (")[0]}${t.reversed ? "(역)" : ""}`).join(" · ");
    lines.push(`카드: ${cards}`);
  }

  return { title: "리딩 기본 정보", body: lines.join("\n") };
}

function buildChatSections(session: ReadingSession): ShareSection[] {
  const followUps = session.messages.slice(2);
  if (followUps.length === 0) return [];
  const sections: ShareSection[] = [];
  for (let i = 0; i < followUps.length; i += 2) {
    const question = followUps[i];
    const answer = followUps[i + 1];
    if (!question) continue;
    const round = Math.floor(i / 2) + 1;
    sections.push({
      title: `더 물어보기 ${round}`,
      body: stripMarkdown(`Q. ${question.content}\n\nA. ${answer?.content ?? ""}`),
    });
  }
  return sections;
}

function chunkLines(lines: string[], size: number): string[][] {
  const chunks: string[][] = [];
  for (let i = 0; i < lines.length; i += size) chunks.push(lines.slice(i, i + size));
  return chunks.length > 0 ? chunks : [[""]];
}

function buildPages(session: ReadingSession): SharePage[] {
  const measureCanvas = document.createElement("canvas");
  const ctx = measureCanvas.getContext("2d");
  if (!ctx) return [];
  ctx.font = "30px Pretendard, Apple SD Gothic Neo, sans-serif";

  const reply = session.messages.find((m) => m.role === "assistant")?.content ?? "";
  const sections = [buildFactsSection(session), ...parseSections(reply), ...buildChatSections(session)];

  return sections.flatMap((section) => {
    const wrapped = wrapText(ctx, section.body, CONTENT_WIDTH);
    const chunks = chunkLines(wrapped, MAX_BODY_LINES);
    return chunks.map((lines, index) => ({
      title: section.title,
      lines,
      part: index + 1,
      totalParts: chunks.length,
    }));
  });
}

function drawPage(session: ReadingSession, page: SharePage, index: number, totalPages: number): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext("2d");
  if (!ctx) return canvas;

  const bg = ctx.createLinearGradient(0, 0, 0, HEIGHT);
  bg.addColorStop(0, "#211a33");
  bg.addColorStop(0.5, "#181423");
  bg.addColorStop(1, "#111019");
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  ctx.strokeStyle = "#a970ff";
  ctx.lineWidth = 6;
  ctx.strokeRect(40, 40, WIDTH - 80, HEIGHT - 80);

  ctx.fillStyle = "#c9a4ff";
  ctx.font = "bold 38px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText("인사이트 오라클", LEFT, 138);

  ctx.fillStyle = "#a89fc4";
  ctx.font = "28px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText(`${TYPE_LABEL[session.type]} · ${new Date(session.createdAt).toLocaleDateString("ko-KR")}`, LEFT, 188);

  ctx.fillStyle = "#f4efff";
  ctx.font = "bold 42px Pretendard, Apple SD Gothic Neo, sans-serif";
  const pageTitle = page.totalParts > 1 ? `${page.title} (${page.part}/${page.totalParts})` : page.title;
  let titleY = 246;
  for (const line of wrapText(ctx, pageTitle, CONTENT_WIDTH).slice(0, 2)) {
    ctx.fillText(line, LEFT, titleY);
    titleY += 48;
  }

  ctx.strokeStyle = "#40365f";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(LEFT, 326);
  ctx.lineTo(WIDTH - LEFT, 326);
  ctx.stroke();

  ctx.fillStyle = "#ece8f7";
  ctx.font = "30px Pretendard, Apple SD Gothic Neo, sans-serif";
  let y = BODY_TOP;
  for (const line of page.lines) {
    if (!line) {
      y += LINE_HEIGHT * 0.7;
      continue;
    }
    ctx.fillText(line, LEFT, y);
    y += LINE_HEIGHT;
  }

  ctx.fillStyle = "#a89fc4";
  ctx.font = "24px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText("이 리딩은 자기이해와 판단 보조용입니다.", LEFT, HEIGHT - 92);
  ctx.textAlign = "right";
  ctx.fillText(`${index + 1} / ${totalPages}`, WIDTH - LEFT, HEIGHT - 92);
  ctx.textAlign = "left";

  return canvas;
}

/** shareGoosebumpImage.ts(C-2 공유 카드)에서도 재사용하는 캔버스→PNG Blob 변환. */
export function canvasToBlob(canvas: HTMLCanvasElement): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob);
      else reject(new Error("이미지를 만들지 못했습니다."));
    }, "image/png");
  });
}

/** shareGoosebumpImage.ts(C-2 공유 카드)에서도 재사용하는 파일명 정제 유틸. */
export function safeFilePart(text: string): string {
  return text
    .replace(/[\\/:*?"<>|]/g, "")
    .replace(/\s+/g, "-")
    .slice(0, 28);
}

/** 리딩 전체를 여러 장의 공유용 카드 이미지로 만들고 ZIP으로 다운로드한다. */
export async function downloadShareImage(session: ReadingSession): Promise<void> {
  const pages = buildPages(session);
  if (pages.length === 0) return;

  const { default: JSZip } = await import("jszip");
  const zip = new JSZip();
  for (let i = 0; i < pages.length; i += 1) {
    const canvas = drawPage(session, pages[i], i, pages.length);
    const blob = await canvasToBlob(canvas);
    const number = String(i + 1).padStart(2, "0");
    zip.file(`${number}-${safeFilePart(pages[i].title)}.png`, blob);
  }

  const zipBlob = await zip.generateAsync({ type: "blob" });
  const url = URL.createObjectURL(zipBlob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `insight-oracle-${session.type}-${session.createdAt.slice(0, 10)}-images.zip`;
  a.click();
  URL.revokeObjectURL(url);
}
