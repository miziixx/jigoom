import { useMemo } from "react";
import { buildConfidenceTiers } from "../lib/selfDeep";
import { computePersonProfile } from "../lib/personDeep";
import type { CompatibilityRelationType, SajuChart } from "../types";

/**
 * 상대 완전분석 미리보기(무료 일부 노출).
 * 결정론 궁합 결과 아래에 "끌리는 지점 한 줄 + 분야별 신뢰도 요약"만 살짝 보여주고,
 * 완전분석(유료 전용, 16항목)으로의 전환을 유도한다.
 */
export default function PersonDeepTeaser({
  chartA,
  chartB,
  relationType,
}: {
  chartA?: SajuChart | null;
  chartB?: SajuChart | null;
  relationType?: CompatibilityRelationType;
}) {
  const preview = useMemo(() => {
    if (!chartB) return null;
    const profile = computePersonProfile(chartB, chartA, relationType);
    const tiers = buildConfidenceTiers({ chart: chartB, hasLuck: false });
    if (!profile && !tiers) return null;
    return { profile, tiers };
  }, [chartA, chartB, relationType]);

  if (!preview) return null;

  return (
    <section className="card person-deep-teaser">
      <div className="section-heading-row">
        <h3 className="card-title">상대 완전분석 미리보기</h3>
        <span className="feature-badge">프리미엄</span>
      </div>
      {preview.profile && <p className="person-deep-teaser__hook">{preview.profile.attractionHeadline}</p>}
      {preview.tiers && <p className="person-deep-teaser__tiers">신뢰도: {preview.tiers.summary}</p>}
      <p className="person-deep-teaser__cta">
        완전분석을 켜면 이 사람이 좋아할 때·불안할 때·질투할 때·식을 때의 행동, 나에게 끌리는 지점과 부담
        지점, 말과 행동이 어긋나는 순간까지 16단계로 자세히 해부해드려요.
      </p>
    </section>
  );
}
