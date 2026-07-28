import { useMemo, useState } from "react";
import type { CSSProperties } from "react";
import {
  buildQualityDashboard,
  getQualityStore,
  isQualityDashboardEnabled,
  type CountEntry,
  type QualityDashboardModel,
} from "../lib/quality";

/**
 * AI Quality Dashboard — 개발자 전용 운영 화면 (/_internal/quality).
 *
 * 관찰자 전용: 계산·리딩 로직을 호출하지 않고, 저장된 QualityEvent를 읽어 뷰-모델을 그린다.
 * 접근 제한: isQualityDashboardEnabled()가 false면 아무것도 보여주지 않는다.
 */

const DOMAIN_LABELS: Record<string, string> = {
  career: "직업·일",
  money: "돈·재물",
  love: "연애·관계",
  health: "건강·컨디션",
  family: "가족",
  move: "이사·이동",
  startup: "창업·독립",
  personality: "성향",
  year: "세운·올해",
  decision: "선택·결정",
  general: "일반",
};

const FORBIDDEN_LABELS: Record<string, string> = {
  "global.no_determinism": "단정 예측(반드시/무조건)",
  "global.no_resignation_order": "퇴사 지시",
  "global.no_investment_promise": "투자·수익 보장",
  "global.no_marriage_certainty": "결혼·재회 확정",
  "global.no_medical_diagnosis": "의학적 진단",
};

function label(map: Record<string, string>, key: string): string {
  return map[key] ?? key;
}

const cardStyle: CSSProperties = { marginBottom: 16 };
const gridStyle: CSSProperties = { display: "grid", gap: 12, gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))" };
const statBox: CSSProperties = { padding: "12px 14px", borderRadius: 10, background: "rgba(127,127,127,0.08)" };
const statNum: CSSProperties = { fontSize: 26, fontWeight: 700, lineHeight: 1.1 };
const statLabel: CSSProperties = { fontSize: 12, opacity: 0.7, marginTop: 4 };
const barTrack: CSSProperties = { height: 8, borderRadius: 6, background: "rgba(127,127,127,0.15)", overflow: "hidden" };

function Bar({ pct, color }: { pct: number; color: string }) {
  return (
    <div style={barTrack}>
      <div style={{ width: `${Math.max(0, Math.min(100, pct))}%`, height: "100%", background: color }} />
    </div>
  );
}

function Stat({ value, title }: { value: number | string; title: string }) {
  return (
    <div style={statBox}>
      <div style={statNum}>{value}</div>
      <div style={statLabel}>{title}</div>
    </div>
  );
}

function healthColor(score: number): string {
  if (score >= 85) return "#2fbf71";
  if (score >= 70) return "#e0a52e";
  return "#e0552e";
}

function CountList({ items, labels }: { items: CountEntry[]; labels?: Record<string, string> }) {
  if (items.length === 0) return <p style={{ opacity: 0.6, fontSize: 13 }}>데이터 없음</p>;
  const max = items[0]?.count ?? 1;
  return (
    <ul style={{ listStyle: "none", padding: 0, margin: 0, display: "grid", gap: 6 }}>
      {items.map((it) => (
        <li key={it.key} style={{ display: "grid", gridTemplateColumns: "1fr auto", gap: 8, alignItems: "center" }}>
          <div>
            <div style={{ fontSize: 13, marginBottom: 3 }}>{labels ? label(labels, it.key) : it.key}</div>
            <Bar pct={(it.count / max) * 100} color="#5b8def" />
          </div>
          <span style={{ fontVariantNumeric: "tabular-nums", opacity: 0.8 }}>{it.count}</span>
        </li>
      ))}
    </ul>
  );
}

function DashboardView({ model, onRefresh, onClear }: { model: QualityDashboardModel; onRefresh: () => void; onClear: () => void }) {
  const { health, metrics, healthTrend } = model;
  return (
    <>
      <section className="card" style={cardStyle}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: 8 }}>
          <div>
            <div style={{ fontSize: 13, opacity: 0.7 }}>AI Engine Health</div>
            <div style={{ fontSize: 46, fontWeight: 800, color: healthColor(health.score) }}>
              {health.score} <span style={{ fontSize: 20, opacity: 0.5 }}>/ 100</span>
            </div>
            <div style={{ fontSize: 12, opacity: 0.7 }}>{health.summary}</div>
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <button onClick={onRefresh}>새로고침</button>
            <button onClick={onClear}>로그 비우기</button>
          </div>
        </div>
        <div style={{ marginTop: 14, display: "grid", gap: 10 }}>
          {health.components.map((c) => (
            <div key={c.key} style={{ display: "grid", gridTemplateColumns: "160px 1fr 90px", gap: 10, alignItems: "center" }}>
              <span style={{ fontSize: 13 }}>
                {c.label} <span style={{ opacity: 0.5 }}>×{c.weight}%</span>
              </span>
              <Bar pct={c.score} color={healthColor(c.score)} />
              <span style={{ fontSize: 12, textAlign: "right", opacity: 0.8 }} title={c.note}>
                {c.score} ({c.contribution})
              </span>
            </div>
          ))}
        </div>
        {healthTrend && (
          <div style={{ marginTop: 12, fontSize: 12, opacity: 0.8 }}>
            <strong>최근 7일 변화: {healthTrend.overallDelta >= 0 ? "+" : ""}{healthTrend.overallDelta}점</strong>
            <ul style={{ margin: "4px 0 0", paddingLeft: 16 }}>
              {healthTrend.notes.map((n, i) => (
                <li key={i}>{n}</li>
              ))}
            </ul>
          </div>
        )}
      </section>

      <section className="card" style={cardStyle}>
        <h3 className="card-title">Reading</h3>
        <div style={gridStyle}>
          <Stat value={metrics.readingCounts.total} title="총 리딩" />
          <Stat value={metrics.readingCounts.today} title="오늘" />
          <Stat value={metrics.readingCounts.thisWeek} title="이번 주" />
          <Stat value={metrics.readingCounts.thisMonth} title="이번 달" />
        </div>
      </section>

      <section className="card" style={cardStyle}>
        <h3 className="card-title">Validation</h3>
        <div style={gridStyle}>
          <Stat value={`${metrics.validation.passRate}%`} title={`pass (${metrics.validation.pass})`} />
          <Stat value={`${metrics.validation.warningRate}%`} title={`warning (${metrics.validation.warning})`} />
          <Stat value={`${metrics.validation.errorRate}%`} title={`error (${metrics.validation.error})`} />
        </div>
      </section>

      <div style={{ display: "grid", gap: 16, gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))" }}>
        <section className="card" style={cardStyle}>
          <h3 className="card-title">Rewrite</h3>
          <div style={gridStyle}>
            <Stat value={`${metrics.rewrite.attemptRate}%`} title="발생률" />
            <Stat value={`${metrics.rewrite.successRate}%`} title={`성공률 (${metrics.rewrite.succeeded}/${metrics.rewrite.attempted})`} />
            <Stat value={metrics.rewrite.failed} title="실패" />
            <Stat value={metrics.rewrite.avgRewritePerReading} title="평균 횟수" />
          </div>
        </section>

        <section className="card" style={cardStyle}>
          <h3 className="card-title">Fallback</h3>
          <div style={gridStyle}>
            <Stat value={`${metrics.fallback.rate}%`} title={`발생률 (${metrics.fallback.count})`} />
          </div>
          <div style={{ marginTop: 10 }}>
            <div style={{ fontSize: 12, opacity: 0.7, marginBottom: 6 }}>사유 TOP</div>
            <CountList items={metrics.fallback.reasonsTop} />
          </div>
        </section>
      </div>

      <section className="card" style={cardStyle}>
        <h3 className="card-title">Confidence — Domain별 평균</h3>
        <div style={{ display: "grid", gap: 8 }}>
          {metrics.confidenceByDomain.length === 0 ? (
            <p style={{ opacity: 0.6, fontSize: 13 }}>데이터 없음</p>
          ) : (
            metrics.confidenceByDomain.map((d) => (
              <div key={d.domain} style={{ display: "grid", gridTemplateColumns: "120px 1fr 80px", gap: 10, alignItems: "center" }}>
                <span style={{ fontSize: 13 }}>{label(DOMAIN_LABELS, d.domain)}</span>
                <Bar pct={d.avgConfidence} color="#7d5bef" />
                <span style={{ fontSize: 12, textAlign: "right", opacity: 0.8 }}>
                  {d.avgConfidence} (n={d.sampleCount})
                </span>
              </div>
            ))
          )}
        </div>
      </section>

      <div style={{ display: "grid", gap: 16, gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))" }}>
        <section className="card" style={cardStyle}>
          <h3 className="card-title">Judgment TOP20</h3>
          <CountList items={metrics.judgmentTop20} />
        </section>
        <section className="card" style={cardStyle}>
          <h3 className="card-title">Rule TOP20</h3>
          <CountList items={metrics.ruleTop20} />
        </section>
      </div>

      <div style={{ display: "grid", gap: 16, gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))" }}>
        <section className="card" style={cardStyle}>
          <h3 className="card-title">Forbidden Claims TOP10</h3>
          <CountList items={metrics.forbiddenClaimsTop10} labels={FORBIDDEN_LABELS} />
        </section>
        <section className="card" style={cardStyle}>
          <h3 className="card-title">Contradiction TOP10</h3>
          <CountList items={metrics.contradictionTop10} />
        </section>
      </div>

      <section className="card" style={cardStyle}>
        <h3 className="card-title">Validation Log — 최근 실패</h3>
        {metrics.recentFailures.length === 0 ? (
          <p style={{ opacity: 0.6, fontSize: 13 }}>최근 실패 없음</p>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 12 }}>
              <thead>
                <tr style={{ textAlign: "left", opacity: 0.7 }}>
                  <th style={{ padding: 6 }}>시간</th>
                  <th style={{ padding: 6 }}>타입</th>
                  <th style={{ padding: 6 }}>사유</th>
                  <th style={{ padding: 6 }}>Rewrite</th>
                  <th style={{ padding: 6 }}>Fallback</th>
                </tr>
              </thead>
              <tbody>
                {metrics.recentFailures.map((f, i) => (
                  <tr key={i} style={{ borderTop: "1px solid rgba(127,127,127,0.15)" }}>
                    <td style={{ padding: 6, whiteSpace: "nowrap" }}>{new Date(f.timestamp).toLocaleString()}</td>
                    <td style={{ padding: 6 }}>{f.readingType}</td>
                    <td style={{ padding: 6 }}>{f.reasonCodes.join(", ") || "-"}</td>
                    <td style={{ padding: 6 }}>{f.rewrite ? "O" : "-"}</td>
                    <td style={{ padding: 6 }}>{f.fallback ? "O" : "-"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <p style={{ fontSize: 11, opacity: 0.5, marginTop: 8 }}>
        schema {model.schemaVersion} · engine {model.engineVersion} · events {model.eventCount} · generated{" "}
        {new Date(model.generatedAt).toLocaleString()} · 개인정보 미저장(코드/플래그/집계만)
      </p>
    </>
  );
}

export default function QualityDashboardPage() {
  const enabled = isQualityDashboardEnabled();
  const [tick, setTick] = useState(0);

  const model = useMemo(() => {
    if (!enabled) return null;
    const events = getQualityStore().readAll();
    return buildQualityDashboard(events);
    // tick으로 수동 새로고침
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled, tick]);

  if (!enabled) {
    return (
      <section className="page">
        <h2 className="page-title">Quality Dashboard</h2>
        <p className="page-desc">
          이 화면은 개발자 전용입니다. 운영 환경에서는 접근이 제한됩니다.
          (개발 모드이거나 VITE_QUALITY_DASHBOARD=1, 또는 localStorage 해제가 필요합니다.)
        </p>
      </section>
    );
  }

  return (
    <section className="page">
      <h2 className="page-title">AI Quality Dashboard</h2>
      <p className="page-desc">개발자 전용 · 엔진 품질 관찰(Observability). 개인정보는 저장하지 않습니다.</p>
      {model && (
        <DashboardView
          model={model}
          onRefresh={() => setTick((t) => t + 1)}
          onClear={() => {
            getQualityStore().clear();
            setTick((t) => t + 1);
          }}
        />
      )}
    </section>
  );
}
