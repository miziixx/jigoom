import {
  NAMING_MODE_LABEL,
  type NameComparison,
  type NameEvaluation,
  type NamingBrief,
  type NamingRecommendOptions,
} from "../lib/naming.js";

export const NAMING_SYSTEM_PROMPT = [
  "당신은 전통 작명 관점의 계산 결과를 사용자가 이해하기 쉬운 생활 언어로 번역하는 이름 감정 해설가다.",
  "계산 자체를 새로 만들거나, 제공되지 않은 한자 뜻·자원오행·획수를 꾸며내지 않는다.",
  "법적 등록 가능성, 인명용 한자 해당 여부, 상표권·상호권 가능성을 확정적으로 말하지 않는다.",
  "사용자가 입력한 이름을 나쁜 이름, 불행한 이름, 피해야 할 이름으로 단정하지 않는다.",
  "발음오행, 사주 보완 기운, 수리성명학은 전통 해석 관점의 참고 자료라고 설명한다.",
  "공포감, 운명 단정, 부모에게 죄책감을 주는 표현을 쓰지 않는다.",
  "좋다/나쁘다로 끝내지 말고, 어떤 점을 살리고 어떤 점을 보완하면 좋은지 현실 행동으로 연결한다.",
  "한자어를 남발하지 말고 쉬운 말을 먼저 쓴다. 전문 용어는 '전문가 근거 보기'에 보존한다.",
  "마크다운 표는 쓰지 않는다. 제목과 bullet은 사용할 수 있다.",
].join("\n");

export const NAMING_RECOMMEND_SYSTEM_PROMPT = [
  "당신은 전통 작명 관점(발음오행·사주 보완)을 근거로 실제 이름 후보를 직접 지어 주는 작명 도우미다.",
  "가장 중요한 임무는 '실제로 쓸 수 있는 구체적인 이름'을 뽑아 주는 것이다. 방향 설명만 하고 실제 이름을 주지 않으면 실패다.",
  "반드시 실제 이름 후보(성이 있으면 성+이름 전체, 한자 표기 포함)를 번호 목록으로 맨 앞에 제시한다.",
  "요청받은 개수만큼 서로 겹치지 않는 이름을 빠짐없이 제시한다. 개수를 줄이거나 '예시'로 얼버무리지 않는다.",
  "제공된 '보완하면 좋은 기운'과 '어울리는 초성' 근거 안에서만 이름을 제안한다. 근거와 무관한 이름을 지어내지 않는다.",
  "각 이름은 자연스럽고 실제로 부르기 좋은 한국 이름이어야 한다. 어색하거나 놀림받기 쉬운 조합은 피한다.",
  "각 이름마다 한글 표기와 한자 표기(예: 民俊 / 백성 민, 뛰어날 준)를 함께 제안한다. 다만 그 한자가 실제 인명용 한자인지, 획수 수리가 어떤지는 단정하지 않고 별도 확인이 필요하다고 안내한다.",
  "특정 이름을 '완벽한 이름', '무조건 좋은 이름'으로 단정하지 않는다. 어디까지나 사주 보완·소리 흐름 관점의 참고 제안이다.",
  "법적 등록 가능성, 인명용 한자 해당 여부, 상표권·상호권 가능성을 확정적으로 말하지 않는다.",
  "공포감, 운명 단정, 부모에게 죄책감을 주는 표현을 쓰지 않는다.",
  "한자어를 남발하지 말고 쉬운 말을 먼저 쓴다.",
  "마크다운 표는 쓰지 않는다. 제목과 bullet, 번호 목록은 사용할 수 있다.",
].join("\n");

export function buildNamingRecommendMessage(brief: NamingBrief, options: NamingRecommendOptions): string {
  const { purpose, school, surname, gender, syllableCount, count } = options;
  const modeLabel = NAMING_MODE_LABEL[purpose.mode];
  const wantCount = count && count > 0 ? count : 6;
  const wantSyllable = syllableCount && syllableCount > 0 ? syllableCount : 2;

  const exampleName = surname?.trim() ? `${surname.trim()}민준` : "민준";
  const exampleHanja = surname?.trim() ? `${surname.trim()}民俊` : "民俊";

  return [
    "[요청]",
    "아래 사주 보완 근거를 바탕으로, 실제로 쓸 수 있는 구체적인 이름 후보를 직접 지어서 제안해라.",
    "방향·기준 설명만 하지 말고, 반드시 실제 이름을 먼저 뽑아 줘라. 이름이 뒤로 밀리면 안 된다.",
    `이름 후보는 정확히 ${wantCount}개, 서로 겹치지 않게 제안한다. 개수를 줄이지 마라.`,
    surname?.trim()
      ? `성(姓)은 '${surname.trim()}'으로 고정하고, 성을 제외한 이름 부분은 ${wantSyllable}글자로 지어라. 각 후보는 '성+이름' 전체로 보여줘라.`
      : `성이 지정되지 않았으니 이름(또는 브랜드·활동명) 부분만 ${wantSyllable}글자 안팎으로 제안해라.`,
    "각 후보는 아래 예시와 똑같은 포맷으로, 한글 이름과 한자 표기를 제목 줄 맨 앞에 굵게 세워라. 그 아래에 근거를 bullet로 붙여라.",
    "",
    "[각 후보 작성 예시 — 이 포맷을 그대로 따라라]",
    `1. **${exampleName}** (${exampleHanja} · 백성 민, 뛰어날 준)`,
    "   - 소리: 사용한 초성과 발음오행이 이 사주 보완 기운에 어떻게 맞는지 한 줄",
    "   - 뜻·이미지: 한자 뜻이 만드는 인상 한 줄",
    "   - 부르는 느낌: 실제로 불렀을 때의 인상 한 줄",
    "",
    "[출력 구조]",
    "# 추천 이름 후보",
    `(위 예시 포맷대로 1번부터 ${wantCount}번까지 실제 이름을 번호 목록으로. 이 섹션을 맨 앞에 둔다.)`,
    "# 이름을 이렇게 골랐어요",
    "(보완 기운과 어울리는 소리 방향을 2~3줄로 쉽게 설명)",
    "# 이름 쓸 때 팁",
    "# 꼭 확인하세요",
    "(인명용 한자·획수 수리·중복·상표 등은 실제 등록/사용 전 별도 확인이 필요하다는 안내)",
    "",
    "[분량]",
    "전체 1100~1700자. 후보 이름은 번호 목록으로 또렷하게, 근거는 짧은 bullet로 정리해라.",
    "",
    "[작명 조건]",
    `작명 목적: ${modeLabel}`,
    `성별/대상 선호: ${gender?.trim() || "미지정 (자연스럽게 반영)"}`,
    `원하는 이미지: ${purpose.desiredImage?.trim() || "미입력"}`,
    `피하고 싶은 발음/느낌: ${purpose.avoidSounds?.trim() || "미입력"}`,
    `추가 메모: ${purpose.purposeNote?.trim() || "미입력"}`,
    `발음오행 기준: ${school === "given-name" ? "이름 중심 기준" : "전체 이름 기준"}`,
    "",
    "[사주 보완 근거 — 이 안에서만 이름을 지어라]",
    `보완하면 좋은 기운: ${brief.neededLabel}`,
    `보완 기운을 직접 담는 초성: ${brief.recommendedChoseong.join(", ")}`,
    brief.supportingChoseong.length
      ? `보완 기운을 상생으로 살려주는 기운: ${brief.supportingLabel} (초성 ${brief.supportingChoseong.join(", ")})`
      : `상생으로 살려주는 기운은 이 사주에선 부담이 될 수 있어 권하지 않음(직접 담는 초성 위주로).`,
    `과하면 부담이 되어 몰리지 않게 할 기운: ${brief.avoidLabel ?? "특별히 없음"}${brief.cautionChoseong.length ? ` (초성 ${brief.cautionChoseong.join(", ")})` : ""}`,
    `근거 요약: ${brief.note}`,
    "",
    "[주의]",
    "이름 후보는 사주 보완·소리 흐름 관점의 참고 제안이며, 절대적인 길흉이 아니라고 자연스럽게 알려라.",
    "아기 이름·개명 이름은 실제 출생신고·개명 신청 전 전자가족관계등록시스템/관할 기관에서 인명용 한자, 글자 수, 동일 이름 등 등록 요건을 최종 확인해야 한다고 안내해라.",
    "예명·활동명·브랜드명은 상표, 도메인, SNS 계정, 기존 사용 여부를 별도로 확인해야 한다고 안내해라.",
  ].join("\n");
}

export function buildNamingUserMessage(evaluation: NameEvaluation, comparison?: NameComparison | null): string {
  const soundLines = evaluation.sound.syllables
    .map((s) => `- ${s.syllable}: 초성 ${s.choseong}, 발음오행 ${s.elementLabel}`)
    .join("\n");
  const relationLines =
    evaluation.sound.relations.length > 0
      ? evaluation.sound.relations.map((r) => `- ${r.from} → ${r.to}: ${r.relation}`).join("\n")
      : "- 인접 음절 관계 없음";
  const suriLines = evaluation.suri
    ? evaluation.suri.levels.map((l) => `- ${l.name}: ${l.total}획, ${l.level}`).join("\n")
    : "- 한자 획수 미입력: 수리 판단은 하지 않음";
  const comparisonLines =
    comparison && comparison.candidates.length > 1
      ? comparison.candidates
          .map(
            (candidate, index) =>
              `- ${index + 1}위 ${candidate.name}: 종합 ${candidate.overall}, 소리 ${candidate.sound.harmony}, 사주 보완 ${candidate.fit.level}, 보완 기운 ${candidate.fit.neededLabel}, 획수 ${candidate.suri ? candidate.suri.summary : "미입력"}`,
          )
          .join("\n")
      : "- 후보 비교 없음";
  const purpose = evaluation.purpose;
  const modeLabel = purpose ? NAMING_MODE_LABEL[purpose.mode] : "일반 이름 감정";

  return [
    "[요청]",
    "아래 이름 감정 계산 결과만 근거로 사용해, 사용자에게 보여줄 이름 해석 리포트를 작성해라.",
    "계산되지 않은 자원오행, 한자 뜻, 실제 법적 작명 적합성은 말하지 마라.",
    "등록 가능 여부, 인명용 한자 여부, 상표·상호 사용 가능성은 최종 확인이 필요한 사항으로만 안내해라.",
    "",
    "[출력 구조]",
    "# 한 줄 결론",
    "# 쉬운 풀이",
    "# 현실에서 느껴지는 인상",
    "# 보완하면 더 좋아지는 점",
    "# 이름을 쓸 때의 팁",
    comparison && comparison.candidates.length > 1 ? "# 후보 비교 종합평" : "",
    "# 전문가 근거 보기",
    "",
    "[분량]",
    "전체 1000~1500자. 짧은 bullet을 섞어 읽기 좋게 써라.",
    "",
    "[계산 결과]",
    `이름: ${evaluation.name}`,
    `작명 목적: ${modeLabel}`,
    `원하는 이미지: ${purpose?.desiredImage?.trim() || "미입력"}`,
    `피하고 싶은 발음/느낌: ${purpose?.avoidSounds?.trim() || "미입력"}`,
    `추가 메모: ${purpose?.purposeNote?.trim() || "미입력"}`,
    `발음오행 기준: ${evaluation.schoolLabel}`,
    `종합 판정: ${evaluation.overall}`,
    `헤드라인: ${evaluation.headline}`,
    "",
    "[후보 비교]",
    comparison?.summary ?? "후보 비교 없음",
    comparisonLines,
    "",
    "[소리의 기운]",
    soundLines,
    `발음오행 흐름 판정: ${evaluation.sound.harmony}`,
    `발음오행 메모: ${evaluation.sound.note}`,
    "",
    "[음절 사이 관계]",
    relationLines,
    "",
    "[사주 보완 적합도]",
    `보완하면 좋은 기운: ${evaluation.fit.neededLabel}`,
    `과하면 부담이 되는 기운: ${evaluation.fit.avoidLabel ?? "없음"}`,
    `보완 기운을 직접 담는가: ${evaluation.fit.suppliesNeeded ? "예" : "아니오"}`,
    `보완 기운을 상생으로 살리는가: ${evaluation.fit.supportsNeeded ? "예" : "아니오"}`,
    `부담 기운으로 쏠리는가: ${evaluation.fit.leansAvoid ? "예" : "아니오"}`,
    `사주 적합도: ${evaluation.fit.level}`,
    `사주 적합도 메모: ${evaluation.fit.note}`,
    "",
    "[획수 수리]",
    suriLines,
    evaluation.suri ? `수리 요약: ${evaluation.suri.summary}` : "수리 요약: 획수 미입력으로 생략",
    "",
    "[주의]",
    "이름은 절대적인 길흉 판정이 아니라, 불릴 때의 소리 흐름과 사주 보완 관점의 참고 자료라고 자연스럽게 설명해라.",
    "아기 이름·개명 이름은 실제 출생신고 또는 개명 신청 전 전자가족관계등록시스템/관할 기관에서 최종 확인이 필요하다고 안내해라.",
    "예명·활동명·브랜드명은 상표, 도메인, SNS 계정, 기존 사용 여부를 별도로 확인해야 한다고 안내해라.",
  ].join("\n");
}
