import { useMemo, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { loadSessions } from "../lib/storage";
import { isPremium, unlockPremium } from "../lib/premium";
import { streamReading } from "../lib/readingApi";
import type { ReadingSession } from "../types";

const TYPE_LABEL: Record<ReadingSession["type"], string> = {
  saju: "사주",
  tarot: "타로",
  combo: "사주+타로",
  today: "오늘의 흐름",
  flow: "월간·연간 흐름",
  mystic: "속마음 리딩",
};

function firstReply(session: ReadingSession): string {
  return session.messages.find((m) => m.role === "assistant")?.content ?? "";
}

function summaryOf(session: ReadingSession): string {
  const sections = firstReply(session)
    .split(/^#\s+.+$/m)
    .filter((s) => s.trim());
  return (sections[0] ?? "").trim();
}

function ReadingColumn({ label, session }: { label: string; session: ReadingSession }) {
  return (
    <div className="card compare-column">
      <h4>
        리딩 {label} · {TYPE_LABEL[session.type]}
      </h4>
      <p className="compare-meta">{new Date(session.createdAt).toLocaleString("ko-KR")}</p>
      <p className="compare-question">Q. {session.question || "(질문 없음)"}</p>
      <p className="reading-body compare-summary">{summaryOf(session)}</p>
    </div>
  );
}

export default function ComparePage() {
  const [searchParams] = useSearchParams();
  const [premium, setPremium] = useState(isPremium());
  const [analysis, setAnalysis] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { sessionA, sessionB } = useMemo(() => {
    const sessions = loadSessions();
    return {
      sessionA: sessions.find((s) => s.id === searchParams.get("a")),
      sessionB: sessions.find((s) => s.id === searchParams.get("b")),
    };
  }, [searchParams]);

  if (!sessionA || !sessionB) {
    return (
      <section className="page">
        <h2 className="page-title">리딩 비교</h2>
        <p className="empty-state">
          비교할 리딩 2개를 찾을 수 없습니다. <Link to="/history">기록</Link>에서 두 개를 선택해주세요.
        </p>
      </section>
    );
  }

  async function runAnalysis() {
    if (!sessionA || !sessionB) return;
    setLoading(true);
    setError(null);
    try {
      const toInput = (s: ReadingSession) => ({
        type: s.type,
        createdAt: s.createdAt,
        question: s.question,
        reply: firstReply(s),
      });
      const result = await streamReading(
        { type: "compare", readingA: toInput(sessionA), readingB: toInput(sessionB) },
        { onText: (accumulated) => setAnalysis(accumulated) },
      );
      setAnalysis(result.reply);
    } catch (err) {
      setError(err instanceof Error ? err.message : "알 수 없는 오류");
    } finally {
      setLoading(false);
    }
  }

  return (
    <section className="page">
      <h2 className="page-title">리딩 비교</h2>
      <p className="page-desc">두 리딩의 핵심 요약을 나란히 보고, 공통 흐름과 달라진 점을 AI로 분석할 수 있습니다.</p>

      <div className="compare-grid">
        <ReadingColumn label="A" session={sessionA} />
        <ReadingColumn label="B" session={sessionB} />
      </div>

      {!analysis &&
        (premium ? (
          <button className="btn btn--primary" onClick={runAnalysis} disabled={loading}>
            {loading ? "비교 분석 중..." : "AI 비교 분석"}
          </button>
        ) : (
          <div className="card premium-gate">
            <p>
              <span className="premium-badge">프리미엄</span> AI 비교 분석은 프리미엄 기능입니다. 두 리딩의 공통
              흐름, 달라진 점, 지금 취할 행동을 정리해드립니다.
            </p>
            <button
              className="btn btn--secondary"
              onClick={() => {
                // 결제 연동 전 체험용 스텁 — 실제 결제 성공 콜백에서 unlockPremium() 호출
                unlockPremium();
                setPremium(true);
              }}
            >
              체험용으로 활성화
            </button>
          </div>
        ))}
      {error && <p className="error-text">{error}</p>}

      {analysis && (
        <div className="card compare-analysis">
          <h3>AI 비교 분석</h3>
          <p className="reading-body">{analysis}</p>
        </div>
      )}

      <Link to="/history" className="btn btn--ghost compare-back">
        기록으로 돌아가기
      </Link>
    </section>
  );
}
