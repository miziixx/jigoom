import { useState } from "react";
import BirthInfoForm from "../components/BirthInfoForm";
import NamingComparison from "../components/NamingComparison";
import NamingResult from "../components/NamingResult";
import { computeSajuChart } from "../lib/saju";
import { generateNamingInterpretation } from "../lib/namingApi";
import { downloadNamingMarkdown } from "../lib/exportNaming";
import {
  compareNames,
  evaluateName,
  SOUND_ELEMENT_SCHOOL_LABEL,
  type NameCandidateInput,
  type NameComparison,
  type NameEvaluation,
  type SoundElementSchool,
} from "../lib/naming";
import type { BirthInfo } from "../types";

export default function NamingPage() {
  const [name, setName] = useState("");
  const [school, setSchool] = useState<SoundElementSchool>("full-name");
  const [candidateText, setCandidateText] = useState("");
  const [strokesText, setStrokesText] = useState("");
  const [result, setResult] = useState<NameEvaluation | null>(null);
  const [comparison, setComparison] = useState<NameComparison | null>(null);
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

  function parseCandidates(text: string): NameCandidateInput[] {
    return text
      .split(/\n+/)
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line) => {
        const [rawName, rawStrokes] = line.split(/[|:]/).map((part) => part.trim());
        return { name: rawName, strokes: rawStrokes ? parseStrokes(rawStrokes) : undefined };
      });
  }

  async function handleSubmit(birthInfo: BirthInfo) {
    const singleName = name.trim();
    const candidates = parseCandidates(candidateText);
    if (!singleName && candidates.length === 0) {
      setError("감정할 이름 또는 비교할 후보 이름을 입력해주세요.");
      return;
    }
    setError(null);
    setInterpretation(null);
    setInterpretationError(null);
    const chart = computeSajuChart(birthInfo);
    const nextComparison =
      candidates.length > 0
        ? compareNames(chart, candidates, school)
        : singleName
          ? compareNames(chart, [{ name: singleName, strokes: parseStrokes(strokesText) }], school)
          : null;
    const nextResult =
      nextComparison?.recommended ?? evaluateName(chart, singleName, parseStrokes(strokesText), school);
    setComparison(nextComparison && nextComparison.candidates.length > 1 ? nextComparison : null);
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
    setComparison(null);
    setInterpretation(null);
    setInterpretationError(null);
    setInterpretationLoading(false);
    setError(null);
  }

  function printNamingReport() {
    window.print();
  }

  return (
    <section className="page">
      <h2 className="page-title">이름 감정</h2>
      <p className="page-desc">
        감정할 이름과 생년월일시를 입력하면, 이름 소리의 기운(발음오행)이 내 사주에서 보완하면 좋은 흐름과 얼마나
        맞는지 계산해 보여드려요. 여러 후보를 넣으면 가장 균형이 좋은 이름부터 비교합니다.
      </p>

      {!result && (
        <>
          <div className="card form">
            <div className="field-row field-row--column">
              <span className="field-label">발음오행 기준</span>
              <div className="segmented naming-school-toggle">
                {(["full-name", "given-name"] as SoundElementSchool[]).map((key) => (
                  <button
                    key={key}
                    type="button"
                    className={school === key ? "segmented__item segmented__item--active" : "segmented__item"}
                    onClick={() => setSchool(key)}
                  >
                    {SOUND_ELEMENT_SCHOOL_LABEL[key]}
                  </button>
                ))}
              </div>
              <span className="field-hint">
                전체 이름 기준은 성까지 포함해 보고, 이름 중심 기준은 성을 고정값으로 두고 이름 부분의 흐름을 더 봅니다.
              </span>
            </div>
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
            <div className="field-row field-row--column">
              <span className="field-label">후보 이름 여러 개 비교 (선택)</span>
              <textarea
                rows={4}
                placeholder={"예:\n김민준 | 8,9,6\n이서아 | 7,8,9\n박도윤"}
                value={candidateText}
                onChange={(e) => setCandidateText(e.target.value)}
              />
              <span className="field-hint">
                줄마다 `이름 | 성·이름 획수`로 입력하세요. 획수를 모르면 이름만 적어도 됩니다. 후보를 입력하면 위 단일 이름보다 후보 비교가 우선됩니다.
              </span>
            </div>
          </div>
          {error && <p className="error-text">{error}</p>}
          <BirthInfoForm submitLabel="이름 감정하기" onSubmit={(b) => handleSubmit(b)} loading={false} showFocus={false} />
        </>
      )}

      {result && (
        <>
          {comparison && <NamingComparison comparison={comparison} />}
          <NamingResult
            result={result}
            interpretation={interpretation}
            interpretationLoading={interpretationLoading}
            interpretationError={interpretationError}
          />
          <div className="naming-actions">
            <button className="btn btn--secondary" onClick={printNamingReport}>
              PDF 저장
            </button>
            <button
              className="btn btn--secondary"
              onClick={() => downloadNamingMarkdown({ result, comparison, interpretation })}
            >
              마크다운 저장
            </button>
            <button className="btn btn--ghost" onClick={reset}>
              다른 이름 감정하기
            </button>
          </div>
        </>
      )}
    </section>
  );
}
