import type { VercelRequest, VercelResponse } from "@vercel/node";
import { computeSajuChart } from "../src/lib/saju.js";
import { hasValidDiagnosticToken } from "./_security.js";

/**
 * 배포 진단용 엔드포인트.
 *
 * 정보 노출을 막기 위해 2단계로 응답한다(P1-2):
 *  - 무인증(토큰 미설정 또는 불일치): { status: "ok" } 최소 응답. 살아있는지만 알려준다.
 *  - 인증(HEALTH_TOKEN env 설정 + 일치하는 x-diagnostic-token 헤더): 런타임/키 존재/모델/엔진 상세.
 *
 * 접근 판정은 _security.ts(프레임워크 무관)에 위임하므로 Vercel 밖에서도 동일하게 동작한다.
 * (API 키 값 자체는 어떤 경우에도 노출하지 않는다.)
 */
export default function handler(req: VercelRequest, res: VercelResponse) {
  // 최소 응답: 정보 노출 0. 로드밸런서/업타임 체크는 이걸로 충분하다.
  if (!hasValidDiagnosticToken(req)) {
    res.status(200).json({ status: "ok" });
    return;
  }

  // 인증된 진단: 상세 정보 노출.
  const result: Record<string, string> = {};
  result.runtime = "ok";
  result.hasApiKey = process.env.ANTHROPIC_API_KEY ? "yes" : "no — 환경변수 ANTHROPIC_API_KEY 없음";
  result.model = process.env.READING_MODEL ?? "claude-sonnet-5 (기본값)";

  try {
    const chart = computeSajuChart({
      calendarType: "solar",
      year: 1990,
      month: 12,
      day: 23,
      hour: 8,
      gender: "female",
    });
    result.sajuEngine = `ok (${chart.year.ganZhi}년 ${chart.month.ganZhi}월 ${chart.day.ganZhi}일)`;
  } catch (err) {
    result.sajuEngine = `error: ${err instanceof Error ? err.message : String(err)}`;
  }

  res.status(200).json(result);
}
