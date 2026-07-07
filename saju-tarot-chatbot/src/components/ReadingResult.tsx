import DefaultReadingTemplate from "./reading/DefaultReadingTemplate";
import YearlyFlowTemplate from "./reading/YearlyFlowTemplate";
import type { ReadingSession } from "../types";

/**
 * 리딩 타입별 결과 템플릿 디스패처.
 * - flow                     → 올해운세형 (1년 작전 지도 배치)
 * - saju + 질문 없음         → 평생사주형 (현행 배치 + 상품 라벨)
 * - saju/combo + 질문 있음   → 고민 상담형 (질문 카드 최상단, 현행 배치)
 * - tarot                    → 타로형 (카드 근거 승격)
 * - 그 외/과거 저장 세션      → 기본 템플릿 폴백
 * ReadingType·프롬프트·저장 구조는 바꾸지 않고 session.type + 질문 유무로만 고른다.
 */
export default function ReadingResult({ session, loading = false }: { session: ReadingSession; loading?: boolean }) {
  const hasQuestion = !!session.question?.trim();

  if (session.type === "flow") {
    return <YearlyFlowTemplate session={session} loading={loading} />;
  }
  if (session.type === "tarot") {
    return (
      <DefaultReadingTemplate session={session} loading={loading} eyebrow="타로 카드 리딩" eyebrowIcon="moonStar" promoteTarotFacts />
    );
  }
  if ((session.type === "saju" || session.type === "combo") && hasQuestion) {
    return <DefaultReadingTemplate session={session} loading={loading} eyebrow="고민 상담 리딩" eyebrowIcon="compass" />;
  }
  if (session.type === "saju") {
    return <DefaultReadingTemplate session={session} loading={loading} eyebrow="평생사주 리포트" eyebrowIcon="book" />;
  }
  if (session.type === "combo") {
    return <DefaultReadingTemplate session={session} loading={loading} eyebrow="사주+타로 통합 리딩" eyebrowIcon="moonStar" />;
  }
  return <DefaultReadingTemplate session={session} loading={loading} />;
}
