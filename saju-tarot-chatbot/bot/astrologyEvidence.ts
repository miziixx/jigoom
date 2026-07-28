// 점성술 계산 근거 두 갈래:
//  1) buildAstrologySummary — 비서 모드(assistantContext) 압축 요약 {sun,moon,ascendant,majorPatterns,transit}.
//  2) buildAstrologyEvidenceText — 점성술 전용 리딩(teacher 경로)용 *전체 근거*.
//     계산 엔진은 현대·고전·베딕을 다 내놓는데 예전엔 여기서 얇은 요약만 넘겼다(가장 큰 낭비).
//     이제 전체 프로파일 + 각도 + 트랜짓 + 구조화된 해석 힌트를 통째로 넘긴다(사주 buildNatalEvidence처럼).
import { computeAstrologyProfile, computeMajorAspects, computeCurrentTransitTheme } from "../src/lib/astrology.js";
import { buildAstrologyInterpretationHints } from "../src/lib/astrologyInterpretation.js";
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

/**
 * 점성술 전용 리딩의 전체 근거 블록. askTeacher()의 evidenceBlocks에 그대로 첨부한다.
 * 예전의 얇은 요약 대신 전체 프로파일(현대·고전·베딕) + 각도 + 오늘 트랜짓 + 구조화된 해석 힌트를
 * 통째로 넘겨, 계산된 깊이가 해석에 다 실리게 한다.
 */
export function buildAstrologyEvidenceText(birthInfo: BirthInfo): string {
  const profile = computeAstrologyProfile(birthInfo);
  const aspects = computeMajorAspects(profile);
  const transit = computeCurrentTransitTheme(profile);
  const hints = buildAstrologyInterpretationHints(profile, aspects);

  const blocks = [
    "[점성술 계산 데이터 — astronomy-engine이 출생 좌표로 정확히 계산한 값. 현대(트로피컬)·고전(헬레니즘)·베딕(시데리얼) 세 전통. 이 안의 값만 근거로 하고, 없는 행성·배치를 지어내지 마세요]",
    JSON.stringify({ profile, aspects, transit }),
    "",
    "[해석 힌트 — 위 배치의 표준 상징 의미를 프로그램이 붙인 것. 참고하되 사용자가 실제 물어본 것에 맞춰 풀어 쓰고, 세 전통을 따로 읊지 말고 겹치는 주제부터 엮으세요]",
    JSON.stringify(hints),
  ];
  if (!profile.timeKnown) {
    blocks.push(
      "",
      "(출생시간 미상 — 상승궁·하우스·앵글·오늘 트랜짓 하우스는 계산에서 빠졌습니다. 행성 별자리 중심으로만 답하고 그 한계를 짧게 밝히세요.)",
    );
  }
  return blocks.join("\n");
}
