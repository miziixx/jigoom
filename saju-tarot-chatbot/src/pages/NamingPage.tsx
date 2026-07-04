import { useState } from "react";
import BirthInfoForm from "../components/BirthInfoForm";
import NamingResult from "../components/NamingResult";
import { computeSajuChart } from "../lib/saju";
import { generateNamingInterpretation } from "../lib/namingApi";
import { evaluateName, type NameEvaluation } from "../lib/naming";
import type { BirthInfo } from "../types";

export default function NamingPage() {
  const [name, setName] = useState("");
  const [strokesText, setStrokesText] = useState("");
  const [result, setResult] = useState<NameEvaluation | null>(null);
  const [interpretation, setInterpretation] = useState<string | null>(null);
  const [interpretationLoading, setInterpretationLoading] = useState(false);
  const [interpretationError, setInterpretationError] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  function parseStrokes(text: string): number[] | undefined {
    const nums = text
      .split(/[,\s·]+/)
      .map((t) => Number(t.trim()))
      .filter((n) => Number.isFinite(n) && n > 0);
    return nums.length >= 2 ? nums : undefined;
  }

  async function handleSubmit(birthInfo: BirthInfo) {
    const trimmed = name.trim();
    if (!trimmed) {
      setError("감정할 이름을 입력해주세요.");
      return;
    }
    setError(null);
    setInterpretation(null);
    setInterpretationError(null);
    const chart = computeSajuChart(birthInfo);
    const nextResult = evaluateName(chart, trimmed, parseStrokes(strokesText));
    setResult(nextResult);
    setInterpretationLoading(true);
    try {
      setInterpretation(await generateNamingInterpretation(nextResult));
    } catch (err) {
      setInterpretationError(err instanceof Error ? err.message : "이름 해석을 불러오지 못했습니다.");
    } finally {
      setInterpretationLoading(false);
    }
  }

  function reset() {
    setResult(null);
    setInterpretation(null);
    setInterpretationError(null);
    setInterpretationLoading(false);
    setError(null);
  }

  return (
    <section className="page">
      <h2 className="page-title">이름 감정</h2>
      <p className="page-desc">
        감정할 이름과 생년월일시를 입력하면, 이름 소리의 기운(발음오행)이 서로 어떻게 이어지는지, 그리고 그 기운이 내
        사주에서 보완하면 좋은 흐름과 얼마나 맞는지를 룰 기반으로 계산해 보여드려요. 한자 획수를 알면 수리도 함께 봅니다.
      </p>

      {!result && (
        <>
          <div className="card form">
            <div className="field-row field-row--column">
              <span className="field-label">감정할 이름</span>
              <input
                type="text"
                placeholder="예: 김민준 (한글로 입력)"
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
            </div>
            <div className="field-row field-row--column">
              <span className="field-label">한자 획수 (선택)</span>
              <input
                type="text"
                placeholder="예: 8, 9, 6 — 성·이름 순서, 모르면 비워두세요"
                value={strokesText}
                onChange={(e) => setStrokesText(e.target.value)}
              />
              <span className="field-hint">획수를 입력하면 원격·형격·이격·정격 수리도 참고로 계산합니다.</span>
            </div>
          </div>
          {error && <p className="error-text">{error}</p>}
          <BirthInfoForm submitLabel="이름 감정하기" onSubmit={(b) => handleSubmit(b)} loading={false} showFocus={false} />
        </>
      )}

      {result && (
        <>
          <NamingResult
            result={result}
            interpretation={interpretation}
            interpretationLoading={interpretationLoading}
            interpretationError={interpretationError}
          />
          <button className="btn btn--ghost" onClick={reset}>
            다른 이름 감정하기
          </button>
        </>
      )}
    </section>
  );
}
