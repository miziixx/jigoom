import { canvasToBlob, safeFilePart, wrapText } from "./shareImage.js";
import type { GoosebumpConfirmation } from "../types";

/**
 * 소름 엔진(C-1) 공유 카드 (C-2, 재기획안 §7 point 3: "적중 순간 공유 카드 1장 제안").
 *
 * shareImage.ts의 캔버스 유틸(wrapText·canvasToBlob·safeFilePart)을 재활용하되, 색감은 이
 * 파일 고유의 보라색 그라데이션 테마를 따르지 않고 앱의 실제 한지 팔레트(index.css)를 그대로
 * 쓴다 — 그라데이션 금지·한지 팔레트 유지는 재기획 전체의 불변식(기획안 §12)이라 신규 카드에는
 * 예외를 두지 않는다. 기존 shareImage.ts(전체 리딩 ZIP)는 재기획 범위 밖이라 손대지 않았다.
 */

const WIDTH = 1080;
const HEIGHT = 1350;
const LEFT = 92;
const CONTENT_WIDTH = WIDTH - LEFT * 2;

// 한지 팔레트(src/index.css :root와 동일 값)
const PALETTE = {
  bg: "#f4ead9",
  surface: "#fffaf1",
  border: "#dac4a0",
  text: "#2f2518",
  textDim: "#765f42",
  accent: "#a97638",
  accentStrong: "#b98246",
};

const ANSWER_LABEL: Record<GoosebumpConfirmation["answer"], string> = {
  yes: "적중",
  no: "빗나감",
  unsure: "잘 모르겠음",
};

function drawGoosebumpCard(confirmations: GoosebumpConfirmation[]): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext("2d");
  if (!ctx) return canvas;

  const yesCount = confirmations.filter((c) => c.answer === "yes").length;
  const total = confirmations.length;

  // 배경 — 단색(그라데이션 금지, 기획안 §12)
  ctx.fillStyle = PALETTE.bg;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  ctx.strokeStyle = PALETTE.accent;
  ctx.lineWidth = 6;
  ctx.strokeRect(40, 40, WIDTH - 80, HEIGHT - 80);

  ctx.fillStyle = PALETTE.accent;
  ctx.font = "bold 38px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText("인사이트 오라클", LEFT, 138);

  ctx.fillStyle = PALETTE.textDim;
  ctx.font = "28px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText("과거 흐름, 계산이 먼저 맞혀봤어요", LEFT, 188);

  ctx.fillStyle = PALETTE.text;
  ctx.font = "bold 56px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText(`과거 흐름 ${total}개 중 ${yesCount}개 적중`, LEFT, 280);

  ctx.strokeStyle = PALETTE.border;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(LEFT, 326);
  ctx.lineTo(WIDTH - LEFT, 326);
  ctx.stroke();

  let y = 400;
  ctx.font = "30px Pretendard, Apple SD Gothic Neo, sans-serif";
  for (const c of confirmations) {
    ctx.fillStyle = PALETTE.accentStrong;
    ctx.font = "bold 32px Pretendard, Apple SD Gothic Neo, sans-serif";
    ctx.fillText(`${c.guess.year}년 · ${c.guess.domainLabel} — ${ANSWER_LABEL[c.answer]}`, LEFT, y);
    y += 46;

    ctx.fillStyle = PALETTE.text;
    ctx.font = "28px Pretendard, Apple SD Gothic Neo, sans-serif";
    for (const line of wrapText(ctx, c.guess.prompt, CONTENT_WIDTH).slice(0, 2)) {
      ctx.fillText(line, LEFT, y);
      y += 38;
    }
    y += 30;
  }

  ctx.fillStyle = PALETTE.textDim;
  ctx.font = "24px Pretendard, Apple SD Gothic Neo, sans-serif";
  ctx.fillText("이 결과는 계산된 흐름과 실제 기억을 대조한 참고용입니다.", LEFT, HEIGHT - 92);

  return canvas;
}

/** 소름 엔진 확인 결과를 단일 PNG 카드로 다운로드한다. */
export async function downloadGoosebumpShareImage(confirmations: GoosebumpConfirmation[]): Promise<void> {
  if (confirmations.length === 0) return;
  const canvas = drawGoosebumpCard(confirmations);
  const blob = await canvasToBlob(canvas);
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `insight-oracle-goosebump-${safeFilePart(new Date().toISOString().slice(0, 10))}.png`;
  a.click();
  URL.revokeObjectURL(url);
}
