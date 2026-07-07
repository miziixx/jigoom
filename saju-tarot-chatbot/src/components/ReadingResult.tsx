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
      <DefaultReadingTemplate
        session={session}
        loading={loading}
        eyebrow="타로 카드 리딩"
        eyebrowIcon="moonStar"
        promoteTarotFacts
        nextCta={{
          items: [
            { to: "/tarot", label: "다른 질문으로 다시 뽑기", icon: "moonStar", desc: "새 스프레드로 지금 상황 보기" },
            { to: "/combo", label: "사주까지 함께 보기", icon: "compass", desc: "큰 흐름과 지금 카드를 한 번에" },
            { to: "/tarot-today", label: "오늘의 카드", icon: "sparkle", desc: "하루 분위기 한 장으로" },
          ],
        }}
      />
    );
  }
  if ((session.type === "saju" || session.type === "combo") && hasQuestion) {
    // 고민 상담형: 지금 이 문제를 이어서 파고들도록 유도한다.
    return (
      <DefaultReadingTemplate
        session={session}
        loading={loading}
        eyebrow="고민 상담 리딩"
        eyebrowIcon="compass"
        nextCta={{
          title: "이 고민, 더 파고들려면",
          items: [
            { to: "/combo", label: "사주+타로로 다시 묻기", icon: "moonStar", desc: "카드까지 더해 지금 상황을 재점검" },
            { to: "/flow", label: "올해 흐름 속에서 보기", icon: "calendar", desc: "이 선택의 시기를 12개월 흐름으로" },
            { to: "/compatibility", label: "관계 고민이면 궁합", icon: "heart", desc: "상대와의 관계 구조 분석" },
          ],
        }}
      />
    );
  }
  if (session.type === "saju") {
    // 평생사주형: 인생 지도 → 올해/분야 심화로 자연스럽게 잇는다.
    return (
      <DefaultReadingTemplate
        session={session}
        loading={loading}
        eyebrow="평생사주 리포트"
        eyebrowIcon="book"
        promoteDaYunLifeMap
        nextCta={{
          title: "이어서 보면 좋은 리포트",
          items: [
            { to: "/flow", label: "올해운세 자세히 보기", icon: "calendar", desc: "타고난 구조가 올해 어떻게 움직이는지" },
            { to: "/combo", label: "지금 고민 넣고 상담", icon: "compass", desc: "구체적 선택을 사주+타로로" },
            { to: "/fortune", label: "오늘 운세", icon: "clock", desc: "오늘 하루의 흐름 참고" },
          ],
        }}
      />
    );
  }
  if (session.type === "combo") {
    return (
      <DefaultReadingTemplate
        session={session}
        loading={loading}
        eyebrow="사주+타로 통합 리딩"
        eyebrowIcon="moonStar"
        nextCta={{
          items: [
            { to: "/flow", label: "올해운세 자세히 보기", icon: "calendar", desc: "올해 12개월 흐름까지" },
            { to: "/saju", label: "전체 사주 리포트", icon: "book", desc: "타고난 구조 정리" },
          ],
        }}
      />
    );
  }
  return <DefaultReadingTemplate session={session} loading={loading} />;
}
