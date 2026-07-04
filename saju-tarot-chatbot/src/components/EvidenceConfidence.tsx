import type { ReadingSession } from "../types";

function confidenceOf(session: ReadingSession): { label: string; score: number; detail: string } {
  let score = 45;
  const details: string[] = [];
  if (session.sajuChart) {
    score += 25;
    details.push("사주 원국 계산값");
  }
  if (session.luckCycles) {
    score += 15;
    details.push("대운·세운·월운 흐름");
  }
  if (session.tarotCards && session.tarotCards.length > 0) {
    score += 10;
    details.push("뽑힌 카드");
  }
  if (session.birthInfo?.hour !== null && session.birthInfo?.hour !== undefined) {
    score += 5;
    details.push("출생 시간");
  }
  if (session.context?.timeAccuracy && session.context.timeAccuracy !== "exact") score -= 10;
  const capped = Math.max(35, Math.min(95, score));
  return {
    label: capped >= 80 ? "근거 충분" : capped >= 60 ? "근거 보통" : "참고 중심",
    score: capped,
    detail: details.length > 0 ? details.join(" · ") : "질문과 리딩 본문 중심",
  };
}

export default function EvidenceConfidence({ session }: { session: ReadingSession }) {
  const confidence = confidenceOf(session);
  const hasUncertainTime = session.context?.timeAccuracy && session.context.timeAccuracy !== "exact";

  return (
    <section className="card evidence-confidence">
      <div className="section-heading-row">
        <h3 className="card-title">근거 신뢰도</h3>
        <span className="feature-badge">{confidence.label}</span>
      </div>
      <div className="evidence-confidence__meter" aria-label={`근거 신뢰도 ${confidence.score}%`}>
        <span style={{ width: `${confidence.score}%` }} />
      </div>
      <p>{confidence.detail}을 바탕으로 해석합니다.</p>
      {hasUncertainTime && (
        <p className="evidence-confidence__note">출생 시간 오차가 있어 시간에 민감한 세부 판단은 참고 범위로 보는 편이 좋아요.</p>
      )}
    </section>
  );
}
