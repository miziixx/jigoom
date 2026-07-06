import { Fragment } from "react";
import { NAMING_MODE_LABEL, type NameEvaluation } from "../lib/naming";
import { parseBodyParts, parseSections, renderTextBlock } from "../lib/readingText";
import ArcGauge from "./viz/ArcGauge";
import RatingCell, { type RatingLevel } from "./viz/RatingCell";
import { VizIcon } from "./viz/icons";

const LEVEL_KEY: Record<string, string> = { 좋음: "good", 보통: "ok", 주의: "warn", 순조로움: "good", 무난함: "ok", "다소 부딪힘": "warn", 길: "good", 평: "ok", 흉: "warn" };

function levelClass(level: string): string {
  return `naming-badge naming-badge--${LEVEL_KEY[level] ?? "ok"}`;
}

const RATING_BY_LEVEL: Record<string, RatingLevel> = { 좋음: "good", 보통: "mid", 주의: "caution" };

/** 좋음/보통/주의 3단계를 아크 게이지 위치로 바꾼다. 숫자는 표시하지 않고 단어만 노출한다. */
const FIT_GAUGE_POSITION: Record<string, number> = { 좋음: 78, 보통: 55, 주의: 38 };

const RELATION_META: Record<string, { cls: "good" | "ok" | "warn"; word: string }> = {
  상생: { cls: "good", word: "밀어줌" },
  상극: { cls: "warn", word: "부딪힘" },
  같음: { cls: "ok", word: "나란함" },
};

/** 발음오행 흐름 다이어그램: 음절 노드(오행 틴트) + 관계 화살표(단어 병기). */
function NameSoundFlow({ sound }: { sound: NameEvaluation["sound"] }) {
  if (sound.syllables.length === 0) return null;
  const flowText = sound.syllables.map((s) => `${s.syllable}(${s.elementLabel})`).join(" → ");

  return (
    <div className="name-sound-flow" role="img" aria-label={`발음오행 흐름: ${flowText}`}>
      {sound.syllables.map((s, i) => {
        const rel = i > 0 ? sound.relations[i - 1] : null;
        const meta = rel ? (RELATION_META[rel.relation] ?? { cls: "ok" as const, word: rel.relation }) : null;
        return (
          <Fragment key={`${s.syllable}-${i}`}>
            {rel && meta && (
              <span className={`name-sound-flow__arrow name-sound-flow__arrow--${meta.cls}`} aria-hidden="true">
                <svg viewBox="0 0 40 14" focusable="false">
                  {meta.cls === "warn" ? (
                    <path d="M2 7h8l4-4 6 8 4-4h8" fill="none" />
                  ) : (
                    <path d="M2 7h30" fill="none" />
                  )}
                  <path d="M32 3l6 4-6 4" fill="none" />
                </svg>
                <small>
                  {rel.relation} · {meta.word}
                </small>
              </span>
            )}
            <span className={`name-sound-flow__node name-sound-flow__node--${s.element}`}>
              <b>{s.syllable}</b>
              <small>
                {s.choseong} · {s.elementLabel}
              </small>
            </span>
          </Fragment>
        );
      })}
    </div>
  );
}

/** AI 해석 섹션 제목 → 아이콘. 못 찾으면 책 아이콘으로 폴백. */
function interpIcon(title: string): string {
  if (/인상|이미지|첫/.test(title)) return "sparkle";
  if (/소리|발음|부를/.test(title)) return "wave";
  if (/보완|기운|사주/.test(title)) return "sprout";
  if (/주의|조심/.test(title)) return "alertTriangle";
  if (/활용|추천|제안|바로/.test(title)) return "checkCircle";
  return "book";
}

/**
 * AI 해석 리포트 본문. "# 제목"/"[소제목]" 구조면 섹션 카드로,
 * 평문이면 문단/불릿으로 렌더한다 — 어떤 출력이 와도 원문 <pre>보다 깔끔하게 폴백된다.
 */
function InterpretationBody({ text }: { text: string }) {
  const sections = parseSections(text);
  const hasHeadings = !(sections.length === 1 && sections[0].title === "리딩 결과");

  if (!hasHeadings) {
    return <div className="naming-interpretation__body">{renderTextBlock(text)}</div>;
  }

  return (
    <div className="naming-interpretation__body">
      {sections.map((sec) => (
        <section className="naming-interp-section" key={sec.title}>
          <h5>
            <VizIcon name={interpIcon(sec.title)} size={14} /> {sec.title}
          </h5>
          {parseBodyParts(sec.body).map((part, i) => (
            <div className="naming-interp-part" key={part.title ?? `intro-${i}`}>
              {part.title && <h6>{part.title}</h6>}
              {renderTextBlock(part.body)}
            </div>
          ))}
        </section>
      ))}
    </div>
  );
}

export default function NamingResult({
  result,
  interpretation,
  interpretationLoading = false,
  interpretationError,
}: {
  result: NameEvaluation;
  interpretation?: string | null;
  interpretationLoading?: boolean;
  interpretationError?: string | null;
}) {
  const { name, sound, fit, suri, overall, headline } = result;

  return (
    <div className="naming-result">
      <section className="card naming-hero">
        <div className="naming-hero__top">
          <b className="naming-hero__name">{name}</b>
          <RatingCell rating={RATING_BY_LEVEL[overall] ?? "mid"} word={`종합 ${overall}`} />
        </div>
        <div className="naming-chips naming-chips--compact">
          {result.purpose && <span>{NAMING_MODE_LABEL[result.purpose.mode]}</span>}
          <span>{result.schoolLabel}</span>
        </div>
        <p>{headline}</p>
      </section>

      <section className="card">
        <h4 className="naming-section-title">
          <VizIcon name="wave" size={15} /> 소리의 기운 (발음오행)
        </h4>
        <NameSoundFlow sound={sound} />
        <p className="naming-note">
          <span className={levelClass(sound.harmony)}>{sound.harmony}</span> {sound.note}
        </p>
      </section>

      <section className="card naming-fit">
        <h4 className="naming-section-title">
          <VizIcon name="link" size={15} />{" "}
          {result.purpose?.mode === "stage" && "활동명으로서의 어울림"}
          {result.purpose?.mode === "brand" && "업종·타깃과의 어울림"}
          {(!result.purpose || ["baby", "rename"].includes(result.purpose.mode)) && "내 사주와의 궁합"}
        </h4>
        <div className="naming-fit__row">
          <ArcGauge label="어울림" score={FIT_GAUGE_POSITION[fit.level] ?? 55} tierLabel={fit.level} size="sm" />
          <p className="naming-note">{fit.note}</p>
        </div>
        <div className="naming-chips">
          <span>
            <VizIcon name="sprout" size={13} /> 보완하면 좋은 기운 {fit.neededLabel}
          </span>
          {fit.avoidLabel && (
            <span>
              <VizIcon name="alertTriangle" size={13} /> 과하면 부담 {fit.avoidLabel}
            </span>
          )}
        </div>
      </section>

      {suri && (
        <section className="card">
          <h4 className="naming-section-title">
            <VizIcon name="hash" size={15} /> 획수 수리 (참고)
          </h4>
          <div className="naming-suri-scroll">
            <table className="naming-suri-table">
              <thead>
                <tr>
                  <th scope="col">격</th>
                  <th scope="col">획수 합</th>
                  <th scope="col">판정</th>
                </tr>
              </thead>
              <tbody>
                {suri.levels.map((l) => (
                  <tr key={l.name}>
                    <th scope="row">{l.name}</th>
                    <td>{l.total}획</td>
                    <td>
                      <span className={levelClass(l.level)}>{l.level}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="naming-note">{suri.summary}</p>
        </section>
      )}

      <section className="card naming-interpretation">
        <h4 className="naming-section-title">
          <VizIcon name="book" size={15} />{" "}
          {result.purpose?.mode === "stage" && "AI 활동명 해석 리포트"}
          {result.purpose?.mode === "brand" && "AI 브랜드명 해석 리포트"}
          {(!result.purpose || ["baby", "rename"].includes(result.purpose.mode)) && "AI 이름 해석 리포트"}
        </h4>
        {interpretationLoading && (
          <p className="naming-note">
            {result.purpose?.mode === "stage"
              ? "발음·사주 기운·개성을 바탕으로 활동명의 인상과 개선 포인트를 쉬운 문장으로 풀어쓰는 중입니다."
              : result.purpose?.mode === "brand"
              ? "발음·사주 기운·업종 적합성을 바탕으로 브랜드명의 이미지와 타깃 매칭도를 쉬운 문장으로 풀어쓰는 중입니다."
              : "계산 근거를 바탕으로 이름의 인상과 보완 포인트를 쉬운 문장으로 풀어쓰는 중입니다."}
          </p>
        )}
        {interpretationError && <p className="error-text">{interpretationError}</p>}
        {interpretation && <InterpretationBody text={interpretation} />}
        {!interpretationLoading && !interpretation && !interpretationError && (
          <p className="naming-note">위 계산 결과를 바탕으로 깊은 문장 해석을 불러올 수 있습니다.</p>
        )}
      </section>

      <p className="naming-disclaimer">
        {result.purpose?.mode === "stage"
          ? "활동명 감정은 발음·사주 기운·개성을 바탕으로 한 참고 자료이며, 기존 사용 여부나 저작권·상표·플랫폼 규정은 별도 확인이 필요합니다."
          : result.purpose?.mode === "brand"
          ? "브랜드명 감정은 발음·사주 기운·업종 적합성을 바탕으로 한 참고 자료이며, 상표 등록·도메인·SNS 계정·사업자등록 중복 여부는 별도 확인이 필요합니다."
          : "이름 감정은 절대적인 길흉 예언이 아니라, 발음오행·사주 보완·수리 같은 전통 작명 관점을 계산해 균형을 보여주는 참고 자료입니다. 어떤 이름도 \"나쁜 이름\"으로 단정하지 않습니다."}
      </p>
    </div>
  );
}
