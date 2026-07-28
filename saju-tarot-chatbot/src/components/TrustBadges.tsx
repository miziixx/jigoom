import { Link } from "react-router-dom";
import type { SajuChart } from "../types";

/**
 * 신뢰 배지 표면화 (C-3, 재기획안 §7 point 4).
 *
 * "출생시간 분 단위 보정(진태양시·서머타임)", "4대 고전 교차 검증", "계산 근거 전부 공개" —
 * 기능은 전부 이미 있음(saju.ts의 correctBirthTime·4대 고전 엔진, 결과 화면의 계산 근거 아코디언).
 * 이 컴포넌트는 새 계산을 하지 않고, 이미 계산된 사실을 짧은 배지로 보여주기만 한다.
 */
export default function TrustBadges({ sajuChart }: { sajuChart?: SajuChart }) {
  if (!sajuChart) return null;
  const hasTimeCorrection = (sajuChart.timeCorrection?.applied.length ?? 0) > 0;

  return (
    <div className="trust-badges">
      {hasTimeCorrection && <span className="trust-badge">출생 시각 분 단위 보정 적용</span>}
      <span className="trust-badge">4대 고전 교차 검증</span>
      <span className="trust-badge">계산 근거 전부 공개</span>
      <Link to="/methodology" className="trust-badge trust-badge--link">
        어떻게 계산하나요? ›
      </Link>
    </div>
  );
}
