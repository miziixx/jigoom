import MysticCard from "./MysticCard";
import { CONCERN_LABEL } from "../readingRules";
import type { MysticReadingResult } from "../../../types";

const AREA_LABEL: Record<string, string> = {
  relationship: "관계",
  work: "일",
  money: "돈",
  emotion: "감정",
};

interface Props {
  result: MysticReadingResult;
  readingId: string;
  hasHour: boolean;
}

/** 속마음 리딩 결과 전체 섹션을 카드로 렌더링한다 */
export default function MysticResultView({ result: r, readingId, hasHour }: Props) {
  return (
    <div className="mystic-result">
      {!hasHour && (
        <p className="mystic-hour-note">
          출생시간을 모르는 경우 시주 기반 일부 세부 해석은 달라질 수 있습니다. 아래 리딩은 그 점을 감안해 제공됩니다.
        </p>
      )}

      {/* A. 첫 점괘 */}
      <MysticCard title={r.openingOracle.title} evidence={r.openingOracle.evidence} emphasized>
        <p className="mystic-oracle-sentence">{r.openingOracle.sentence}</p>
      </MysticCard>

      {/* B. 지금 내 상태 */}
      <MysticCard
        title="지금 내 상태"
        summary={r.currentState.summary}
        evidence={r.currentState.evidence}
        readingId={readingId}
        sectionKey="currentState"
      >
        <p>🫀 몸의 신호 — {r.currentState.bodySignal}</p>
        <p>🌊 감정의 흐름 — {r.currentState.emotionalSignal}</p>
        <p>🔋 에너지가 새는 곳 — {r.currentState.energyLeak}</p>
        <p className="mystic-advice">→ {r.currentState.advice}</p>
      </MysticCard>

      {/* C. 말하지 않은 고민 */}
      <MysticCard title="말하지 않은 고민" readingId={readingId} sectionKey="hiddenConcerns">
        <div className="mystic-concern-grid">
          {r.hiddenConcerns.map((c, i) => (
            <div className="mystic-concern" key={i}>
              <span className="mystic-tag">{CONCERN_LABEL[c.category]}</span>
              <strong>{c.title}</strong>
              <p>{c.description}</p>
              <p className="mystic-why">왜 떠오르나 — {c.whyItAppears}</p>
            </div>
          ))}
        </div>
      </MysticCard>

      {/* D. 겉모습과 진짜 내면 */}
      <MysticCard
        title="겉모습과 진짜 내면"
        evidence={r.outerInnerSelf.evidence}
        readingId={readingId}
        sectionKey="outerInnerSelf"
      >
        <p>🪞 남들이 보는 나 — {r.outerInnerSelf.outerSelf}</p>
        <p>🤫 내가 숨기는 마음 — {r.outerInnerSelf.innerSelf}</p>
        <p>🛡️ 상처받을 때 나오는 반응 — {r.outerInnerSelf.defensePattern}</p>
        <p>💭 진짜 원하는 것 — {r.outerInnerSelf.hiddenDesire}</p>
        <p>🥀 무너지는 지점 — {r.outerInnerSelf.collapsePoint}</p>
      </MysticCard>

      {/* E. 반복되는 인생 패턴 */}
      <MysticCard title="반복되는 인생 패턴" readingId={readingId} sectionKey="repeatedPatterns">
        {r.repeatedPatterns.map((p, i) => (
          <div className="mystic-pattern" key={i}>
            <span className="mystic-tag">{AREA_LABEL[p.area] ?? p.area}</span>
            <p>{p.pattern}</p>
            <p className="mystic-why">{p.reason}</p>
            <p className="mystic-advice">→ {p.howToBreak}</p>
          </div>
        ))}
      </MysticCard>

      {/* F. 돈과 일 */}
      <MysticCard title="돈이 붙는 방식과 새는 구멍" readingId={readingId} sectionKey="workAndMoney">
        <p>💰 돈이 붙는 방식 — {r.workAndMoney.moneyAttractionPattern}</p>
        <p>🕳️ 돈이 새는 구멍 — {r.workAndMoney.moneyLeakPattern}</p>
        <p>✅ 잘 맞는 일의 환경 — {r.workAndMoney.suitableWorkEnvironment}</p>
        <p>⚠️ 피해야 할 일의 환경 — {r.workAndMoney.unsuitableWorkEnvironment}</p>
        <p className="mystic-advice">→ {r.workAndMoney.currentAdvice}</p>
      </MysticCard>

      {/* G. 관계 속마음 */}
      <MysticCard title="관계 속마음 리딩" readingId={readingId} sectionKey="relationshipReading">
        <p>💛 내가 기대하는 것 — {r.relationshipReading.expectationPattern}</p>
        <p>💔 내가 상처받는 방식 — {r.relationshipReading.hurtPattern}</p>
        <p>🚪 마음을 닫는 순간 — {r.relationshipReading.closingHeartMoment}</p>
        <p>🌀 반복되는 오해 — {r.relationshipReading.misunderstandingPattern}</p>
        <p className="mystic-advice">→ {r.relationshipReading.advice}</p>
      </MysticCard>

      {/* H. 올해의 전환점 (타임라인) */}
      <MysticCard title="올해 나를 흔드는 흐름" readingId={readingId} sectionKey="yearlyTurningPoints">
        <div className="mystic-timeline">
          {r.yearlyTurningPoints.map((t, i) => (
            <div className="mystic-timeline__item" key={i}>
              <div className="mystic-timeline__period">
                <span className="mystic-timeline__dot" />
                {t.period}
                <span className="mystic-tag">{t.keyword}</span>
              </div>
              <p>기회 — {t.opportunity}</p>
              <p>주의 — {t.caution}</p>
              <p className="mystic-advice">→ {t.advice}</p>
            </div>
          ))}
        </div>
      </MysticCard>

      {/* I. 지금 피해야 할 선택 */}
      <MysticCard title="지금 피해야 할 선택" readingId={readingId} sectionKey="avoidNow">
        {r.avoidNow.map((a, i) => (
          <div className="mystic-choice" key={i}>
            <strong>🚫 {a.title}</strong>
            <p>{a.reason}</p>
            <p className="mystic-advice">→ {a.saferAlternative}</p>
          </div>
        ))}
      </MysticCard>

      {/* J. 지금 해야 할 선택 */}
      <MysticCard title="지금 해야 할 선택" readingId={readingId} sectionKey="doNow">
        {r.doNow.map((d, i) => (
          <div className="mystic-choice" key={i}>
            <strong>✅ {d.title}</strong>
            <p>{d.action}</p>
            <p className="mystic-why">{d.reason}</p>
          </div>
        ))}
      </MysticCard>

      {/* K. 마지막 점괘 */}
      <MysticCard title="마지막 점괘" emphasized>
        <p className="mystic-oracle-sentence">{r.closingOracle.sentence}</p>
        <p className="mystic-why">{r.closingOracle.theme}</p>
      </MysticCard>
    </div>
  );
}
