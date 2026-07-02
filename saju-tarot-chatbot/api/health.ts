import type { VercelRequest, VercelResponse } from "@vercel/node";
import { computeSajuChart } from "../src/lib/saju";

/**
 * 배포 진단용: 함수 런타임 / 사주 계산 모듈 / 환경변수 존재 여부를 확인한다.
 * (API 키 값 자체는 절대 노출하지 않는다)
 */
export default function handler(_req: VercelRequest, res: VercelResponse) {
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
