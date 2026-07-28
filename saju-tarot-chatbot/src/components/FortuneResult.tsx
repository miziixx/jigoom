import { useState } from "react";
import ArcGauge from "./viz/ArcGauge";
import { SealStamp } from "./viz/Motif";
import { VizIcon } from "./viz/icons";
import type { FortuneCategoryContent, FortuneResult as FortuneResultType } from "../types";

interface CategoryCardDef {
  label: string;
  score: number;
  content: FortuneCategoryContent;
}

const CATEGORY_ICON: Record<string, string> = {
  재물: "coin",
  애정: "heart",
  "직장·학업": "briefcase",
  건강: "leaf",
  대인관계: "people",
};

function CategoryCard({ label, score, content }: CategoryCardDef) {
  return (
    <div className="fortune-category-card">
      <span className="fortune-category-card__icon" aria-hidden="true">
        <VizIcon name={CATEGORY_ICON[label] ?? "dots"} size={15} />
      </span>
      <ArcGauge label={label} score={score} size="sm" />
      <p className="fortune-category-card__comment">{content.comment}</p>
      {content.good && (
        <p className="fortune-badge fortune-badge--good">
          <VizIcon name="check" size={12} /> {content.good}
        </p>
      )}
      {content.caution && (
        <p className="fortune-badge fortune-badge--caution">
          <VizIcon name="alertTriangle" size={12} /> {content.caution}
        </p>
      )}
    </div>
  );
}

export default function FortuneResult({ result }: { result: FortuneResultType }) {
  const { evidence: e, content, source } = result;
  const [copied, setCopied] = useState(false);

  const categoryCards: CategoryCardDef[] = [
    { label: "재물", score: e.categories.money, content: content.categories.money },
    { label: "애정", score: e.categories.love, content: content.categories.love },
    { label: "직장·학업", score: e.categories.career, content: content.categories.career },
    { label: "건강", score: e.categories.health, content: content.categories.health },
    { label: "대인관계", score: e.categories.relationship, content: content.categories.relationship },
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
          <span className="fortune-ganzhi fortune-ganzhi--seal" title="오늘의 일진 간지">
            <SealStamp text={e.ganzhi.day} />
            <small>일진 {e.ganzhi.day}</small>
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

      {/* 2) 전체 운세 */}
      <section className="card fortune-overall-card">
        <h3 className="card-title">오늘의 총운</h3>
        <ArcGauge label="총운" score={e.categories.overall} size="lg" />
        <p className="fortune-overall">{content.overall}</p>
      </section>

      {/* 3) 분야별 카드 */}
      <section className="card">
        <h3 className="card-title">분야별 운세</h3>
        <div className="fortune-category-grid">
          {categoryCards.map((c) => (
            <CategoryCard key={c.label} {...c} />
          ))}
        </div>
      </section>

      {/* 4) 추천 / 피할 행동 */}
      <section className="card fortune-two">
        <div className="fortune-two__panel fortune-two__panel--good">
          <h4 className="fortune-subhead fortune-subhead--good">
            <VizIcon name="check" size={14} /> 추천 행동
          </h4>
          <ul className="fortune-ul fortune-ul--icons">
            {content.do_actions.map((s, i) => (
              <li key={i}>
                <VizIcon name="checkCircle" size={14} className="fortune-li-icon fortune-li-icon--good" />
                <span>{s}</span>
              </li>
            ))}
          </ul>
        </div>
        <div className="fortune-two__panel fortune-two__panel--caution">
          <h4 className="fortune-subhead fortune-subhead--caution">
            <VizIcon name="alertTriangle" size={14} /> 피할 행동
          </h4>
          <ul className="fortune-ul fortune-ul--icons">
            {content.avoid_actions.map((s, i) => (
              <li key={i}>
                <VizIcon name="alertTriangle" size={14} className="fortune-li-icon fortune-li-icon--caution" />
                <span>{s}</span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* 5) 행운 아이템 */}
      <section className="card">
        <h3 className="card-title">오늘의 행운</h3>
        <div className="lucky-grid">
          <div className="lucky-item">
            <span className="lucky-item__label">
              <VizIcon name="palette" size={13} /> 색
            </span>
            <span className="lucky-item__value">{e.luckyItems.colors.join(", ")}</span>
          </div>
          <div className="lucky-item">
            <span className="lucky-item__label">
              <VizIcon name="compass" size={13} /> 방향
            </span>
            <span className="lucky-item__value">{e.luckyItems.direction}</span>
          </div>
          <div className="lucky-item">
            <span className="lucky-item__label">
              <VizIcon name="hash" size={13} /> 숫자
            </span>
            <span className="lucky-item__value">{e.luckyItems.numbers.join(", ")}</span>
          </div>
          <div className="lucky-item">
            <span className="lucky-item__label">
              <VizIcon name="clock" size={13} /> 시간대
            </span>
            <span className="lucky-item__value">
              {e.luckyItems.timeSlot.zhi}시 ({e.luckyItems.timeSlot.range})
            </span>
          </div>
        </div>
        <p className="lucky-note">기준 오행: {e.luckyItems.element} (용신 후보)</p>
      </section>

      {/* 6) 왜 이런 운세인가요 (근거) */}
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

      {/* 7) 공유 */}
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
