import { useState } from "react";
import BirthInfoForm from "../components/BirthInfoForm";
import NamingComparison from "../components/NamingComparison";
import NamingRecommendResult from "../components/NamingRecommendResult";
import NamingResult from "../components/NamingResult";
import { computeSajuChart } from "../lib/saju";
import { generateNamingInterpretation, generateNameRecommendations } from "../lib/namingApi";
import { getCachedResult, setCachedResult } from "../lib/resultCache";
import { downloadNamingMarkdown } from "../lib/exportNaming";
import { downloadNamingImages } from "../lib/shareNamingImage";
import {
  buildNamingBrief,
  compareNames,
  evaluateName,
  parseRecommendedNames,
  scoreRecommendedNames,
  NAMING_MODE_LABEL,
  SOUND_ELEMENT_SCHOOL_LABEL,
  type NameCandidateInput,
  type NameComparison,
  type NameEvaluation,
  type NamingBrief,
  type NamingMode,
  type NamingPurpose,
  type ScoredRecommendedName,
  type SoundElementSchool,
} from "../lib/naming";

import type { BirthInfo } from "../types";

const RECOMMEND_COUNT = 24;

// 오행 한 글자(목/화/토/금/수)를 쉬운 말 뜻으로 (칩이 "수"처럼 숫자로 읽히는 혼동 방지)
const ELEMENT_MEANING: Record<string, string> = {
  목: "성장·시작",
  화: "표현·활력",
  토: "안정·책임",
  금: "판단·정리",
  수: "생각·휴식",
};

type NamingTab = "evaluate" | "recommend";

const OFFICIAL_NAMING_LINKS = {
  efamilyHanja: "https://efamily.scourt.go.kr/cs/CsBltnWrtList.do?bltnbordId=0000010",
  easyLawName: "https://www.easylaw.go.kr/CSP/CnpClsMain.laf?ccfNo=2&cciNo=1&cnpClsNo=2&csmSeq=1830",
};

export default function NamingPage() {
  const [tab, setTab] = useState<NamingTab>("evaluate");
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

  // 이름 추천 탭 상태
  const [surname, setSurname] = useState("");
  const [gender, setGender] = useState("");
  const [syllableCount, setSyllableCount] = useState(2);
  const [brief, setBrief] = useState<NamingBrief | null>(null);
  const [lastRecommendBirth, setLastRecommendBirth] = useState<BirthInfo | null>(null);
  const [recommendation, setRecommendation] = useState<string | null>(null);
  const [recommendScored, setRecommendScored] = useState<ScoredRecommendedName[]>([]);
  const [recommendDirection, setRecommendDirection] = useState<string | null>(null);
  const [recommendLoading, setRecommendLoading] = useState(false);
  const [recommendError, setRecommendError] = useState<string | null>(null);

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
    const evalKey = { ev: nextResult, comparison: nextComparison };
    try {
      const cached = getCachedResult<string>("naming-evaluate", evalKey);
      const reply = cached ?? (await generateNamingInterpretation(nextResult, nextComparison));
      if (!cached) setCachedResult("naming-evaluate", evalKey, reply);
      setInterpretation(reply);
    } catch (err) {
      setInterpretationError(err instanceof Error ? err.message : "이름 해석을 불러오지 못했습니다.");
    } finally {
      setInterpretationLoading(false);
    }
  }

  async function handleRecommend(birthInfo: BirthInfo, forceRegenerate = false) {
    setError(null);
    setRecommendError(null);
    setRecommendation(null);
    setRecommendScored([]);
    setRecommendDirection(null);
    const chart = computeSajuChart(birthInfo);
    const nextBrief = buildNamingBrief(chart);
    const purpose: NamingPurpose = {
      mode,
      desiredImage: desiredImage.trim() || undefined,
      avoidSounds: avoidSounds.trim() || undefined,
      purposeNote: purposeNote.trim() || undefined,
    };
    setBrief(nextBrief);
    setLastRecommendBirth(birthInfo);
    setRecommendLoading(true);
    const options = {
      purpose,
      school,
      surname: surname.trim() || undefined,
      gender: gender.trim() || undefined,
      syllableCount,
      count: RECOMMEND_COUNT,
    };
    const recKey = { brief: nextBrief, options };
    try {
      const cached = forceRegenerate ? null : getCachedResult<string>("naming-recommend-v3", recKey);
      const reply = cached ?? (await generateNameRecommendations(nextBrief, options));
      setCachedResult("naming-recommend-v3", recKey, reply);
      // AI는 후보만 뽑고, 점수는 사주 차트로 결정론적으로 매긴다.
      const parsed = parseRecommendedNames(reply);
      if (parsed) {
        setRecommendScored(
          scoreRecommendedNames(chart, parsed, { surname: surname.trim() || undefined, school, purpose }),
        );
        setRecommendDirection(parsed.direction ?? null);
      } else {
        setRecommendScored([]);
        setRecommendDirection(null);
      }
      setRecommendation(reply);
    } catch (err) {
      setRecommendError(err instanceof Error ? err.message : "이름 추천을 불러오지 못했습니다.");
    } finally {
      setRecommendLoading(false);
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

  function resetRecommend() {
    setBrief(null);
    setLastRecommendBirth(null);
    setRecommendation(null);
    setRecommendScored([]);
    setRecommendDirection(null);
    setRecommendError(null);
    setRecommendLoading(false);
    setError(null);
  }

  function switchTab(next: NamingTab) {
    if (next === tab) return;
    setTab(next);
    setError(null);
  }

  function printNamingReport() {
    window.print();
  }

  return (
    <section className="page">
      <h2 className="page-title">이름 감정 · 추천</h2>
      <div className="segmented naming-tab-toggle">
        <button
          type="button"
          className={tab === "evaluate" ? "segmented__item segmented__item--active" : "segmented__item"}
          onClick={() => switchTab("evaluate")}
        >
          이름 감정
        </button>
        <button
          type="button"
          className={tab === "recommend" ? "segmented__item segmented__item--active" : "segmented__item"}
          onClick={() => switchTab("recommend")}
        >
          이름 추천
        </button>
      </div>
      <p className="page-desc">
        {tab === "evaluate"
          ? "감정할 이름과 생년월일시를 입력하면, 이름 소리의 기운(발음오행)이 내 사주에서 보완하면 좋은 흐름과 얼마나 맞는지 계산해 보여드려요. 여러 후보를 넣으면 가장 균형이 좋은 이름부터 비교합니다."
          : "생년월일시와 성·원하는 이미지를 입력하면, 사주에서 보완하면 좋은 기운을 계산하고 그 기운에 어울리는 소리(발음오행)를 근거로 이름 후보를 추천해 드려요. 한자 뜻도 함께 제안하되, 실제 등록은 별도 확인이 필요해요."}
      </p>

      {tab === "evaluate" && !result && (
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

      {tab === "evaluate" && result && (
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
            <button
              className="btn btn--secondary"
              onClick={() => void downloadNamingImages({ result, comparison, interpretation })}
            >
              이미지 ZIP 저장
            </button>
            <button className="btn btn--ghost" onClick={reset}>
              다른 이름 감정하기
            </button>
          </div>
        </>
      )}

      {tab === "recommend" && !recommendation && (
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
                      {key === "baby" && "새로 지을 아기 이름"}
                      {key === "rename" && "지금과 다른 이미지의 개명 이름"}
                      {key === "stage" && "활동 분야에 어울리는 예명·활동명"}
                      {key === "brand" && "부르기 쉬운 상호·브랜드명"}
                    </span>
                  </button>
                ))}
              </div>
            </div>
            <div className="field-row field-row--column">
              <span className="field-label">성 (선택)</span>
              <input
                type="text"
                placeholder="예: 김 — 아기·개명은 성을 넣으면 성+이름으로 추천해요"
                value={surname}
                onChange={(e) => setSurname(e.target.value)}
              />
              <span className="field-hint">예명·브랜드명은 성 없이 이름 부분만 추천받아도 됩니다.</span>
            </div>
            <div className="field-row field-row--column">
              <span className="field-label">성별·대상 선호 (선택)</span>
              <input
                type="text"
                placeholder="예: 남아, 여아, 중성적인 느낌"
                value={gender}
                onChange={(e) => setGender(e.target.value)}
              />
            </div>
            <div className="field-row field-row--column">
              <span className="field-label">이름 글자 수 (성 제외)</span>
              <div className="segmented naming-school-toggle">
                {[1, 2, 3].map((n) => (
                  <button
                    key={n}
                    type="button"
                    className={syllableCount === n ? "segmented__item segmented__item--active" : "segmented__item"}
                    onClick={() => setSyllableCount(n)}
                  >
                    {n}글자
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
          </div>
          {error && <p className="error-text">{error}</p>}
          <div className="card naming-legal-note">
            <b>등록·법적 확인 안내</b>
            <p>
              추천 이름은 사주 보완·발음오행 관점의 참고 제안입니다. 아기 이름·개명 이름은 실제 출생신고 또는 개명 신청 전
              전자가족관계등록시스템이나 관할 기관에서 인명용 한자, 이름 글자 수, 동일 이름 등 등록 요건을 최종 확인해야 합니다.
              예명·상호·브랜드명은 상표, 도메인, SNS 계정, 기존 사용 여부를 별도로 확인하세요.
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
          <BirthInfoForm
            submitLabel={recommendLoading ? "추천 받는 중..." : "이름 추천받기"}
            onSubmit={(b) => handleRecommend(b)}
            loading={recommendLoading}
            showFocus={false}
          />
        </>
      )}

      {tab === "recommend" && recommendation && (
        <div className="naming-result">
          {brief && (
            <section className="card naming-hero">
              <div className="naming-hero__top">
                <b className="naming-hero__name">이름 추천</b>
                <span className="naming-badge naming-badge--good">보완 기운 {brief.neededLabel}</span>
              </div>
              <div className="naming-chips">
                <span>어울리는 초성 {brief.recommendedChoseong.join(" · ")}</span>
                {/* 살려주는 기운은 실제로 도움이 되는 경우(초성이 있을 때)만 표시.
                    보완 기운과 부담 기운이 겹치는 특수 케이스에선 모순되므로 감춘다. */}
                {brief.supportingChoseong.length > 0 && (
                  <span>
                    함께 살리면 좋은 {brief.supportingLabel} 기운({ELEMENT_MEANING[brief.supportingLabel] ?? "기운"})
                  </span>
                )}
                {brief.avoidLabel && (
                  <span>
                    많으면 부담되는 {brief.avoidLabel} 기운({ELEMENT_MEANING[brief.avoidLabel] ?? "기운"})
                  </span>
                )}
              </div>
              <p>{brief.note}</p>
            </section>
          )}
          {recommendScored.length > 0 ? (
            <NamingRecommendResult direction={recommendDirection} candidates={recommendScored} topCount={5} />
          ) : (
            <section className="card naming-interpretation">
              <h4 className="naming-section-title">AI 이름 추천</h4>
              <pre className="naming-interpretation__text">{recommendation}</pre>
            </section>
          )}
          <p className="naming-disclaimer">
            추천 이름은 절대적인 길흉 예언이 아니라, 발음오행·사주 보완 관점으로 어울리는 소리를 계산해 제안한 참고 자료입니다.
            한자·획수·인명용 여부와 실제 등록 요건은 반드시 별도로 확인하세요.
          </p>
          <div className="naming-actions">
            <button className="btn btn--secondary" onClick={printNamingReport}>
              PDF 저장
            </button>
            {lastRecommendBirth && (
              <button
                className="btn btn--secondary"
                onClick={() => void handleRecommend(lastRecommendBirth, true)}
                disabled={recommendLoading}
              >
                {recommendLoading ? "생성 중..." : "🔄 다시 생성"}
              </button>
            )}
            <button className="btn btn--ghost" onClick={resetRecommend}>
              새 조건으로
            </button>
          </div>
        </div>
      )}

      {tab === "recommend" && !recommendation && recommendError && <p className="error-text">{recommendError}</p>}
    </section>
  );
}
