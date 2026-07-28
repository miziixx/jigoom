import { useState } from "react";
import type { FortuneResult as FortuneResultType } from "../types";

interface GaugeDef {
  label: string;
  score: number;
  comment?: string;
}

function band(score: number): "high" | "mid" | "low" {
  if (score >= 62) return "high";
  if (score >= 45) return "mid";
  return "low";
}

function Gauge({ label, score, comment }: GaugeDef) {
  return (
    <div className="gauge">
      <div className="gauge__head">
        <span className="gauge__label">{label}</span>
        <span className="gauge__score">{score}</span>
      </div>
      <div className="gauge__track">
        <span className={`gauge__fill gauge__fill--${band(score)}`} style={{ width: `${score}%` }} />
      </div>
      {comment && <p className="gauge__comment">{comment}</p>}
    </div>
  );
}

export default function FortuneResult({ result }: { result: FortuneResultType }) {
  const { evidence: e, content, source } = result;
  const [copied, setCopied] = useState(false);

  const gauges: GaugeDef[] = [
    { label: "총운", score: e.categories.overall },
    { label: "재물", score: e.categories.money, comment: content.categories.money },
    { label: "애정", score: e.categories.love, comment: content.categories.love },
    { label: "직장·학업", score: e.categories.career, comment: content.categories.work },
    { label: "건강", score: e.categories.health, comment: content.categories.condition },
    { label: "대인관계", score: e.categories.relationship, comment: content.categories.relationship },
  ];

  const activeRelations = e.branchRelations.filter((r) => r.relations.length > 0);

  async function copyShare() {
    try {
      await navigator.clipboard.writeText(content.share_text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      // 클립보드 접근이 막힌 환경: 사용자에게 텍스트를 노출해 직접 복사하도록
      window.prompt("아래 내용을 복사하세요", content.share_text);
    }
  }

  return (
    <div className="fortune-result">
      {/* 1) 상단: 날짜 + 일진 + 총평 + 키워드 */}
      <section className="card fortune-hero">
        <div className="fortune-hero__top">
          <span className="fortune-date">
            {e.date} ({e.weekday})
          </span>
          <span className="fortune-ganzhi" title="오늘의 일진 간지">
            일진 {e.ganzhi.day}
          </span>
        </div>
        <p className="fortune-summary">{content.summary}</p>
        <div className="chips">
          {content.keywords.slice(0, 3).map((k, i) => (
            <span className="chip" key={i}>
              #{k}
            </span>
          ))}
        </div>
        {source === "fallback" && (
          <p className="fortune-note">※ 지금은 간이(룰 기반) 문장으로 표시 중이에요. 점수·근거는 정확히 계산된 값입니다.</p>
        )}
      </section>

      {/* 2) 카테고리 점수 게이지 */}
      <section className="card">
        <h3 className="card-title">오늘의 점수</h3>
        <div className="gauge-list">
          {gauges.map((g) => (
            <Gauge key={g.label} {...g} />
          ))}
        </div>
      </section>

      {/* good / caution */}
      <section className="card fortune-two">
        <div>
          <h4 className="fortune-subhead fortune-subhead--good">잘 풀리는 영역</h4>
          <ul className="fortune-ul">
            {content.good_areas.map((s, i) => (
              <li key={i}>{s}</li>
            ))}
          </ul>
        </div>
        <div>
          <h4 className="fortune-subhead fortune-subhead--caution">오늘 체크할 포인트</h4>
          <ul className="fortune-ul">
            {content.caution_points.map((s, i) => (
              <li key={i}>{s}</li>
            ))}
          </ul>
        </div>
      </section>

      {/* 3) 추천 / 피할 행동 */}
      <section className="card fortune-two">
        <div>
          <h4 className="fortune-subhead fortune-subhead--good">추천 행동</h4>
          <ul className="fortune-ul">
            {content.do_actions.map((s, i) => (
              <li key={i}>{s}</li>
            ))}
          </ul>
        </div>
        <div>
          <h4 className="fortune-subhead fortune-subhead--caution">피할 행동</h4>
          <ul className="fortune-ul">
            {content.avoid_actions.map((s, i) => (
              <li key={i}>{s}</li>
            ))}
          </ul>
        </div>
      </section>

      {/* 4) 행운 아이템 */}
      <section className="card">
        <h3 className="card-title">오늘의 행운</h3>
        <div className="lucky-grid">
          <div className="lucky-item">
            <span className="lucky-item__label">색</span>
            <span className="lucky-item__value">{e.luckyItems.colors.join(", ")}</span>
          </div>
          <div className="lucky-item">
            <span className="lucky-item__label">방향</span>
            <span className="lucky-item__value">{e.luckyItems.direction}</span>
          </div>
          <div className="lucky-item">
            <span className="lucky-item__label">숫자</span>
            <span className="lucky-item__value">{e.luckyItems.numbers.join(", ")}</span>
          </div>
          <div className="lucky-item">
            <span className="lucky-item__label">시간대</span>
            <span className="lucky-item__value">
              {e.luckyItems.timeSlot.zhi}시 ({e.luckyItems.timeSlot.range})
            </span>
          </div>
        </div>
        <p className="lucky-note">기준 오행: {e.luckyItems.element} (용신 후보)</p>
      </section>

      {/* 5) 왜 이런 운세인가요 (근거) */}
      <details className="card reading-section fortune-why">
        <summary>왜 이런 운세인가요?</summary>
        <div className="fortune-why__body">
          <p>
            <strong>십성</strong> — 내 일간 {e.natal.dayMaster}({e.natal.dayMasterElement})가 오늘 일진 천간 {e.ganzhi.dayGan}을(를)
            만나 <b>{e.tenGod.name}</b>({e.tenGod.group})가 됩니다. {e.tenGod.axis}
          </p>
          <p>
            <strong>지지 관계</strong> —{" "}
            {activeRelations.length > 0
              ? activeRelations.map((r) => `${r.position} ${r.myBranch}↔${r.todayBranch} ${r.relations.join("·")}`).join(", ")
              : "오늘 지지와 뚜렷한 합충 관계가 없어 원국을 크게 흔들지 않는 무난한 날입니다."}
          </p>
          <p>
            <strong>오행 조력도</strong> — {e.elementSupport.score > 0 ? "+" : ""}
            {e.elementSupport.score} / 100. {e.elementSupport.detail}
          </p>
          <p>
            <strong>12운성</strong> — 오늘 지지 {e.ganzhi.dayZhi}에서 일간의 기운은 <b>{e.twelveStage.stage}</b> (에너지{" "}
            {e.twelveStage.energyLevel}/100)입니다.
          </p>
          <p>
            <strong>신살</strong> — {e.sinsal.hits.length > 0 ? e.sinsal.hits.join(", ") : "오늘 해당하는 신살은 없습니다."}
          </p>
          <p className="fortune-why__natal">
            원국: 연주 {e.natal.pillars.year} / 월주 {e.natal.pillars.month} / 일주 {e.natal.pillars.day}
            {e.natal.pillars.hour ? ` / 시주 ${e.natal.pillars.hour}` : " (시주 제외)"} · {e.natal.strength} · 용신 후보{" "}
            {e.natal.yongshin.join("·") || "없음"}
          </p>
        </div>
      </details>

      {/* 6) 공유 */}
      <div className="reading-actions">
        <button className="btn btn--secondary" onClick={copyShare}>
          {copied ? "복사됨 ✓" : "운세 공유하기 (복사)"}
        </button>
      </div>

      <p className="fortune-disclaimer">
        본 콘텐츠는 엔터테인먼트 / 자기성찰용입니다. 건강·법률·투자·결혼·이직 등 중대한 결정의 근거로 사용하지 마세요.
      </p>
    </div>
  );
}
