// 점성술 계산 근거를 새 비서 모드(assistantContext.astrologySummary)용으로 압축한다.
// evidence.ts가 사주 원국 전체 JSON을 근거로 넘기는 것과 달리, 여기는 스펙이 요구하는
// {sun, moon, ascendant, majorPatterns, currentTransitTheme} 형태로만 정리한다.
import { computeAstrologyProfile, computeMajorAspects, computeCurrentTransitTheme } from "../src/lib/astrology.js";
import type { BirthInfo } from "../src/types/index.js";

export interface AstrologySummary {
  sun: string;
  moon: string;
  ascendant: string;
  majorPatterns: string[];
  currentTransitTheme: string;
}

function placementLine(p: { sign: string; degree: number; keyword: string } | undefined, fallback: string): string {
  if (!p) return fallback;
  return `${p.sign} ${Math.floor(p.degree)}도 (${p.keyword})`;
}

/**
 * 점성술 요약을 만든다. 생년월일시(BirthInfo)가 필요하다 — 사주팔자만 직접 입력한
 * 사용자는 출생일 자체가 없어 점성술 계산이 불가하므로 null을 반환한다.
 */
export function buildAstrologySummary(birthInfo: BirthInfo): AstrologySummary {
  const profile = computeAstrologyProfile(birthInfo);
  const aspects = computeMajorAspects(profile);
  const transit = computeCurrentTransitTheme(profile);

  const majorPatterns = [
    ...aspects.slice(0, 6).map((a) => `${a.bodyA}-${a.bodyB} ${a.aspect}(orb ${a.orb}도)`),
    ...profile.classical.placements
      .filter((p) => p.dignity === "도미사일" || p.dignity === "엑잘테이션")
      .map((p) => `${p.body} ${p.dignity}`),
  ];

  return {
    sun: placementLine(profile.modern.sun, "계산 불가"),
    moon: placementLine(profile.modern.moon, "계산 불가"),
    ascendant: profile.modern.ascendant ? placementLine(profile.modern.ascendant, "계산 불가") : "출생시간 없어 계산 불가",
    majorPatterns: majorPatterns.length > 0 ? majorPatterns : ["뚜렷한 주요 각도 패턴 적음"],
    currentTransitTheme: transit.theme,
  };
}

/** askTeacher()의 evidenceBlocks에 그대로 첨부할 수 있는 텍스트 블록 형태로 만든다. */
export function buildAstrologyEvidenceText(birthInfo: BirthInfo): string {
  const summary = buildAstrologySummary(birthInfo);
  return `[점성술 계산 데이터 — 프로그램이 출생 좌표로 정확히 계산한 값. 이 안의 값만 근거로 해석하세요]\n${JSON.stringify(summary)}`;
}
