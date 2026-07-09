import { useMemo, useState } from "react";
import { buildGoosebumpReport } from "../lib/goosebumpEngine";
import { computePastYearRawSignals } from "../lib/saju";
import { saveGoosebumpConfirmation } from "../lib/goosebumpStorage";
import type { BirthInfo, GoosebumpAnswer, GoosebumpGuess, SajuChart } from "../types";

const ANSWER_LABEL: Record<GoosebumpAnswer, string> = {
  yes: "맞아요",
  no: "아니에요",
  unsure: "잘 모르겠어요",
};

/**
 * 소름 엔진 (C-1, 재기획안 §7) — 무료 기본 리딩 블록 1.
 *
 * pastValidation(사용자가 과거 사건을 입력하면 채점)과 반대 방향: 시스템이 먼저 계산된 대운·세운에서
 * 신호가 가장 강한 과거 2~3개 (연도, 분야)를 골라 "맞나요?"로 묻는다. 확인/부인은 로컬에 저장돼
 * 신뢰 배지(C-3)·공유 카드(C-2)의 재료가 된다.
 *
 * saju.ts 호출(computePastYearRawSignals)이 필요해 basicReadingRenderer.ts(가벼운 렌더러, saju.ts
 * 비의존 원칙)에 넣지 않고 별도 컴포넌트로 뺐다 — monthFlowNarrative.ts와 같은 이유(무거운
 * lunar-javascript를 가벼운 모듈 그래프에 끌고 오지 않기 위함).
 */
export default function GoosebumpCheck({
  birthInfo,
  sajuChart,
}: {
  birthInfo?: BirthInfo;
  sajuChart?: SajuChart;
}) {
  const guesses = useMemo(() => {
    if (!birthInfo || !sajuChart?.dayMasterGan) return [];
    const currentYear = new Date().getFullYear();
    const startYear = Math.max(birthInfo.year + 1, currentYear - 15);
    const endYear = currentYear - 1;
    if (startYear > endYear) return [];
    const years = Array.from({ length: endYear - startYear + 1 }, (_, i) => startYear + i);
    const signals = computePastYearRawSignals(birthInfo, years);
    return buildGoosebumpReport(sajuChart.dayMasterGan, signals).guesses;
  }, [birthInfo, sajuChart]);

  const [answers, setAnswers] = useState<Partial<Record<number, GoosebumpAnswer>>>({});

  if (guesses.length === 0) return null;

  function handleAnswer(guess: GoosebumpGuess, answer: GoosebumpAnswer) {
    setAnswers((prev) => ({ ...prev, [guess.year]: answer }));
    saveGoosebumpConfirmation({ guess, answer, answeredAt: new Date().toISOString() });
  }

  const answeredEntries = Object.entries(answers) as [string, GoosebumpAnswer][];
  const allAnswered = answeredEntries.length === guesses.length;
  const yesCount = answeredEntries.filter(([, a]) => a === "yes").length;

  return (
    <section className="card goosebump-check">
      <div className="section-heading-row">
        <h3 className="card-title">과거 흐름, 먼저 맞혀볼게요</h3>
        <span className="feature-badge">무료 · 즉시</span>
      </div>
      <p className="goosebump-check__note">계산만으로 과거 중 흐름이 강했던 시기를 먼저 짚어봤어요. 실제로 그랬는지 확인해주세요.</p>
      <ul className="goosebump-check__list">
        {guesses.map((g) => {
          const answered = answers[g.year];
          return (
            <li className="goosebump-check__item" key={g.year}>
              <p className="goosebump-check__prompt">{g.prompt}</p>
              {answered ? (
                <span className="goosebump-check__answered">{ANSWER_LABEL[answered]}</span>
              ) : (
                <div className="goosebump-check__buttons">
                  <button type="button" className="btn btn--secondary btn--small" onClick={() => handleAnswer(g, "yes")}>
                    맞아요
                  </button>
                  <button type="button" className="btn btn--secondary btn--small" onClick={() => handleAnswer(g, "no")}>
                    아니에요
                  </button>
                  <button type="button" className="btn btn--ghost btn--small" onClick={() => handleAnswer(g, "unsure")}>
                    잘 모르겠어요
                  </button>
                </div>
              )}
            </li>
          );
        })}
      </ul>
      {allAnswered && (
        <p className="goosebump-check__summary">
          과거 흐름 {guesses.length}개 중 {yesCount}개 적중했어요.
        </p>
      )}
    </section>
  );
}
