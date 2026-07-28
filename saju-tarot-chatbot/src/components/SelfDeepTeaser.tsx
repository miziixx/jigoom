import { useMemo } from "react";
import { buildCapacityAxes } from "../lib/capacityAxis";
import { buildPsychLayer } from "../lib/psychLayer";
import { buildConfidenceTiers, deriveShadow } from "../lib/selfDeep";
import type { ReadingSession } from "../types";

/**
 * 자기 완전분석 미리보기(무료 일부 노출).
 * 일반 사주 리딩 결과에 그림자 한 줄 + 분야별 신뢰도 요약만 살짝 보여주고,
 * 완전분석(유료 전용, 12블록)으로의 전환을 유도한다. 이미 완전분석 리딩이면 렌더하지 않는다.
 */
export default function SelfDeepTeaser({ session }: { session: ReadingSession }) {
  const preview = useMemo(() => {
    const chart = session.sajuChart;
    if (!chart) return null;
    const shadow = deriveShadow(buildPsychLayer(chart), buildCapacityAxes(chart));
    const tiers = buildConfidenceTiers({
      chart,
      hasLuck: Boolean(session.luckCycles),
      timeAccuracy: session.context?.timeAccuracy,
    });
    if (!shadow && !tiers) return null;
    return { shadow, tiers };
  }, [session.sajuChart, session.luckCycles, session.context?.timeAccuracy]);

  // 완전분석 리딩 자체에는 미리보기를 붙이지 않는다(본문이 이미 전부 다룬다).
  if (session.context?.analysisMode === "selfDeep") return null;
  if (!preview) return null;

  return (
    <section className="card self-deep-teaser">
      <div className="section-heading-row">
        <h3 className="card-title">완전분석 미리보기</h3>
        <span className="feature-badge">프리미엄</span>
      </div>
      {preview.shadow && <p className="self-deep-teaser__shadow">{preview.shadow.headline}</p>}
      {preview.tiers && <p className="self-deep-teaser__tiers">신뢰도: {preview.tiers.summary}</p>}
      <p className="self-deep-teaser__cta">
        완전분석을 켜면 겉과 속, 감정 구조, 반복 패턴, 그림자·결핍까지 12단계로 자세히 해부해드려요. 새로
        볼 때 "자기 완전분석"을 선택해보세요.
      </p>
    </section>
  );
}
