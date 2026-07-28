import { buildNamingMarkdown } from "./exportNaming";
import type { NameComparison, NameEvaluation } from "./naming";

interface NamingImageInput {
  result: NameEvaluation;
  comparison?: NameComparison | null;
  interpretation?: string | null;
}

interface NamingImagePage {
  title: string;
  lines: string[];
  part: number;
  totalParts: number;
}

const WIDTH = 1080;
const HEIGHT = 1350;
const LEFT = 92;
const CONTENT_WIDTH = WIDTH - LEFT * 2;
const BODY_TOP = 330;
const BODY_BOTTOM = HEIGHT - 132;
const LINE_HEIGHT = 42;
const MAX_BODY_LINES = Math.floor((BODY_BOTTOM - BODY_TOP) / LINE_HEIGHT);

function stripMarkdown(text: string): string {
  return text
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/__(.+?)__/g, "$1")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/^\s*[-*+]\s+/gm, "• ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function safeFilePart(text: string): string {
  return text.replace(/[\\/:*?"<>|]/g, "").replace(/\s+/g, "-").slice(0, 28);
}

function wrapText(ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string[] {
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

function chunkLines(lines: string[], size: number): string[][] {
  const chunks: string[][] = [];
  for (let i = 0; i < lines.length; i += size) chunks.push(lines.slice(i, i + size));
  return chunks.length > 0 ? chunks : [[""]];
}

function sectionsFromMarkdown(markdown: string): { title: string; body: string }[] {
  const parts = markdown.split(/^##\s+(.+)$/m).slice(1);
  const intro = markdown.split(/^##\s+.+$/m)[0]?.trim();
  const sections = intro ? [{ title: "작명 기본 정보", body: stripMarkdown(intro) }] : [];
  for (let i = 0; i < parts.length; i += 2) {
    sections.push({ title: parts[i].trim(), body: stripMarkdown(parts[i + 1] ?? "") });
  }
  return sections;
}

function buildPages(input: NamingImageInput): NamingImagePage[] {
  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d");
  if (!ctx) return [];
  ctx.font = "29px Pretendard, Apple SD Gothic Neo, sans-serif";

  return sectionsFromMarkdown(buildNamingMarkdown(input)).flatMap((section) => {
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

function drawPage(input: NamingImageInput, page: NamingImagePage, index: number, totalPages: number): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext("2d");
  if (!ctx) return canvas;

  const bg = ctx.createLinearGradient(0, 0, 0, HEIGHT);
  bg.addColorStop(0, "#251b35");
  bg.addColorStop(0.58, "#171421");
  bg.addColorStop(1, "#101017");
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  ctx.strokeStyle = "#74d7b8";
  ctx.lineWidth = 5;
  ctx.strokeRect(40, 40, WIDTH - 80, HEIGHT - 80);

  ctx.fillStyle = "#74d7b8";
  ctx.font = "bold 36px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText("사주 기반 작명 리포트", LEFT, 130);

  ctx.fillStyle = "#c9a4ff";
  ctx.font = "bold 48px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText(input.result.name, LEFT, 198);

  ctx.fillStyle = "#a89fc4";
  ctx.font = "26px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText(`${input.result.overall} · ${input.result.schoolLabel}`, LEFT, 242);

  ctx.fillStyle = "#f4efff";
  ctx.font = "bold 40px Pretendard, Apple SD Gothic Neo, sans-serif";
  const pageTitle = page.totalParts > 1 ? `${page.title} (${page.part}/${page.totalParts})` : page.title;
  let titleY = 292;
  for (const line of wrapText(ctx, pageTitle, CONTENT_WIDTH).slice(0, 2)) {
    ctx.fillText(line, LEFT, titleY);
    titleY += 46;
  }

  ctx.strokeStyle = "#40365f";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(LEFT, BODY_TOP - 28);
  ctx.lineTo(WIDTH - LEFT, BODY_TOP - 28);
  ctx.stroke();

  ctx.fillStyle = "#ece8f7";
  ctx.font = "29px Pretendard, Apple SD Gothic Neo, sans-serif";
  let y = BODY_TOP;
  for (const line of page.lines) {
    if (!line) {
      y += LINE_HEIGHT * 0.65;
      continue;
    }
    ctx.fillText(line, LEFT, y);
    y += LINE_HEIGHT;
  }

  ctx.fillStyle = "#a89fc4";
  ctx.font = "23px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText("등록 가능 여부는 공식 시스템/기관에서 최종 확인하세요.", LEFT, HEIGHT - 92);
  ctx.textAlign = "right";
  ctx.fillText(`${index + 1} / ${totalPages}`, WIDTH - LEFT, HEIGHT - 92);
  ctx.textAlign = "left";

  return canvas;
}

function canvasToBlob(canvas: HTMLCanvasElement): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob);
      else reject(new Error("이미지를 만들지 못했습니다."));
    }, "image/png");
  });
}

export async function downloadNamingImages(input: NamingImageInput): Promise<void> {
  const pages = buildPages(input);
  if (pages.length === 0) return;

  const { default: JSZip } = await import("jszip");
  const zip = new JSZip();
  for (let i = 0; i < pages.length; i += 1) {
    const canvas = drawPage(input, pages[i], i, pages.length);
    const blob = await canvasToBlob(canvas);
    const number = String(i + 1).padStart(2, "0");
    zip.file(`${number}-${safeFilePart(pages[i].title)}.png`, blob);
  }

  const zipBlob = await zip.generateAsync({ type: "blob" });
  const url = URL.createObjectURL(zipBlob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `naming-report-${safeFilePart(input.result.name)}-images.zip`;
  a.click();
  URL.revokeObjectURL(url);
}
