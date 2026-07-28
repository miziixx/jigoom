import type { ReadingSession } from "../types";

/** 마지막 글자 받침 유무에 따라 "을/를" 목적격 조사를 붙인다. */
function withObjectParticle(word: string): string {
  const lastCode = word.charCodeAt(word.length - 1);
  if (lastCode < 0xac00 || lastCode > 0xd7a3) return `${word}를`;
  const hasBatchim = (lastCode - 0xac00) % 28 !== 0;
  return hasBatchim ? `${word}을` : `${word}를`;
}

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
    const cardCount = session.tarotCards.length;
    // 카드 수(스프레드 크기)가 클수록 여러 자리의 독립적 근거가 쌓이므로 가산폭을 키운다.
    score += Math.min(30, 6 + (cardCount - 1) * 3);
    details.push(cardCount > 1 ? `${cardCount}장 스프레드` : "뽑힌 카드");
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
      <p>{withObjectParticle(confidence.detail)} 바탕으로 해석합니다.</p>
      {hasUncertainTime && (
        <p className="evidence-confidence__note">출생 시간 오차가 있어 시간에 민감한 세부 판단은 참고 범위로 보는 편이 좋아요.</p>
      )}
    </section>
  );
}
