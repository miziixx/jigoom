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
  NAMING_MODE_LABEL,
  SOUND_ELEMENT_SCHOOL_LABEL,
  type NameCandidateInput,
  type NameComparison,
  type NameEvaluation,
  type NamingMode,
  type NamingPurpose,
  type SoundElementSchool,
} from "../lib/naming";
import type { BirthInfo } from "../types";

const OFFICIAL_NAMING_LINKS = {
  efamilyHanja: "https://efamily.scourt.go.kr/cs/CsBltnWrtList.do?bltnbordId=0000010",
  easyLawName: "https://www.easylaw.go.kr/CSP/CnpClsMain.laf?ccfNo=2&cciNo=1&cnpClsNo=2&csmSeq=1830",
};

export default function NamingPage() {
  const [name, setName] = useState("");
  const [mode, setMode] = useState<NamingMode>("baby");
  const [school, setSchool] = useState<SoundElementSchool>("full-name");
  const [candidateText, setCandidateText] = useState("");
  const [strokesText, setStrokesText] = useState("");
  const [desiredImage, setDesiredImage] = useState("");
  const [avoidSounds, setAvoidSounds] = useState("");
  const [purposeNote, setPurposeNote] = useState("");
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
    const purpose: NamingPurpose = {
      mode,
      desiredImage: desiredImage.trim() || undefined,
      avoidSounds: avoidSounds.trim() || undefined,
      purposeNote: purposeNote.trim() || undefined,
    };
    const nextComparison =
      candidates.length > 0
        ? compareNames(chart, candidates, school, purpose)
        : singleName
          ? compareNames(chart, [{ name: singleName, strokes: parseStrokes(strokesText) }], school, purpose)
          : null;
    const nextResult =
      nextComparison?.recommended ?? evaluateName(chart, singleName, parseStrokes(strokesText), school, purpose);
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
              <span className="field-label">작명 목적</span>
              <div className="naming-mode-grid">
                {(["baby", "rename", "stage", "brand"] as NamingMode[]).map((key) => (
                  <button
                    key={key}
                    type="button"
                    className={mode === key ? "naming-mode-card naming-mode-card--active" : "naming-mode-card"}
                    onClick={() => setMode(key)}
                  >
                    <b>{NAMING_MODE_LABEL[key]}</b>
                    <span>
                      {key === "baby" && "출생신고 전 최종 확인이 필요한 이름"}
                      {key === "rename" && "현재 이름과 다른 이미지가 필요한 경우"}
                      {key === "stage" && "활동 분야와 기억되기 쉬운 인상"}
                      {key === "brand" && "상호·브랜드로 부르기 쉬운 이름"}
                    </span>
                  </button>
                ))}
              </div>
            </div>
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
              <span className="field-label">원하는 이미지 (선택)</span>
              <input
                type="text"
                placeholder="예: 단아함, 밝음, 지적임, 고급스러움, 단단함"
                value={desiredImage}
                onChange={(e) => setDesiredImage(e.target.value)}
              />
            </div>
            <div className="field-row field-row--column">
              <span className="field-label">피하고 싶은 발음/느낌 (선택)</span>
              <input
                type="text"
                placeholder="예: 너무 무거운 느낌, 특정 초성, 놀림이 쉬운 발음"
                value={avoidSounds}
                onChange={(e) => setAvoidSounds(e.target.value)}
              />
            </div>
            <div className="field-row field-row--column">
              <span className="field-label">목적 메모 (선택)</span>
              <textarea
                rows={3}
                placeholder="예: 아이가 커서도 어색하지 않은 이름, 직업 이미지에 맞는 활동명, 브랜드 검색에 쓰기 쉬운 이름"
                value={purposeNote}
                onChange={(e) => setPurposeNote(e.target.value)}
              />
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
          <div className="card naming-legal-note">
            <b>등록·법적 확인 안내</b>
            <p>
              이 기능은 사주 보완, 발음오행, 선택 입력한 획수를 바탕으로 한 참고 리포트입니다. 아기 이름·개명 이름은 실제
              출생신고 또는 개명 신청 전 전자가족관계등록시스템이나 관할 기관에서 인명용 한자, 이름 글자 수, 동일 이름 등
              등록 요건을 최종 확인해야 합니다. 예명·상호·브랜드명은 상표, 도메인, SNS 계정, 기존 사용 여부를 별도로 확인하세요.
            </p>
            <div className="naming-legal-links">
              <a href={OFFICIAL_NAMING_LINKS.efamilyHanja} target="_blank" rel="noreferrer">
                인명용 한자 조회
              </a>
              <a href={OFFICIAL_NAMING_LINKS.easyLawName} target="_blank" rel="noreferrer">
                자녀 이름 법령 안내
              </a>
            </div>
          </div>
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
