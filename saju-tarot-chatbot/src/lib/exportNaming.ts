import { NAMING_MODE_LABEL, type NameComparison, type NameEvaluation } from "./naming";

interface NamingExportInput {
  result: NameEvaluation;
  comparison?: NameComparison | null;
  interpretation?: string | null;
}

const OFFICIAL_EFAMILY_HANJA_URL = "https://efamily.scourt.go.kr/cs/CsBltnWrtList.do?bltnbordId=0000010";
const OFFICIAL_EASYLAW_NAME_URL = "https://www.easylaw.go.kr/CSP/CnpClsMain.laf?ccfNo=2&cciNo=1&cnpClsNo=2&csmSeq=1830";

function safeFilenamePart(value: string): string {
  return value.trim().replace(/[\\/:*?"<>|]+/g, "-").replace(/\s+/g, "-") || "name";
}

export function buildNamingMarkdown({ result, comparison, interpretation }: NamingExportInput): string {
  const lines: string[] = [
    "# 이름 감정 리포트",
    "",
    `- 이름: ${result.name}`,
    `- 작명 목적: ${result.purpose ? NAMING_MODE_LABEL[result.purpose.mode] : "일반 이름 감정"}`,
    `- 원하는 이미지: ${result.purpose?.desiredImage ?? "미입력"}`,
    `- 피하고 싶은 발음/느낌: ${result.purpose?.avoidSounds ?? "미입력"}`,
    `- 목적 메모: ${result.purpose?.purposeNote ?? "미입력"}`,
    `- 발음오행 기준: ${result.schoolLabel}`,
    `- 종합 판정: ${result.overall}`,
    `- 한 줄 결론: ${result.headline}`,
    "",
  ];

  if (comparison) {
    lines.push("## 후보 이름 비교", "", comparison.summary, "");
    for (const [index, candidate] of comparison.candidates.entries()) {
      lines.push(
        `### ${index + 1}. ${candidate.name}`,
        "",
        `- 종합: ${candidate.overall}`,
        `- 소리 흐름: ${candidate.sound.harmony}`,
        `- 사주 보완: ${candidate.fit.level} / 보완하면 좋은 기운 ${candidate.fit.neededLabel}`,
        `- 획수 참고: ${candidate.suri ? candidate.suri.summary : "획수 미입력"}`,
        "",
      );
    }
  }

  lines.push(
    "## 소리의 기운",
    "",
    ...result.sound.syllables.map((s) => `- ${s.syllable}: ${s.choseong} / ${s.elementLabel}`),
    "",
    `- 흐름 판정: ${result.sound.harmony}`,
    `- 해석: ${result.sound.note}`,
    "",
    "## 내 사주와의 궁합",
    "",
    `- 보완하면 좋은 기운: ${result.fit.neededLabel}`,
    `- 과하면 부담이 되는 기운: ${result.fit.avoidLabel ?? "없음"}`,
    `- 판정: ${result.fit.level}`,
    `- 해석: ${result.fit.note}`,
    "",
  );

  if (result.suri) {
    lines.push("## 획수 수리", "");
    for (const level of result.suri.levels) {
      lines.push(`- ${level.name}: ${level.total}획 / ${level.level}`);
    }
    lines.push("", result.suri.summary, "");
  }

  if (interpretation) {
    lines.push("## AI 이름 해석 리포트", "", interpretation.trim(), "");
  }

  lines.push(
    "## 주의 안내",
    "",
    "이름 감정은 절대적인 길흉 예언이 아니라, 발음오행·사주 보완·수리 같은 전통 작명 관점을 계산해 균형을 보여주는 참고 자료입니다. 어떤 이름도 나쁜 이름으로 단정하지 않습니다.",
    "아기 이름·개명 이름은 실제 출생신고 또는 개명 신청 전 전자가족관계등록시스템이나 관할 기관에서 인명용 한자, 이름 글자 수, 동일 이름 등 등록 요건을 최종 확인해야 합니다.",
    "예명·활동명·상호명·브랜드명은 상표, 도메인, SNS 계정, 기존 사용 여부를 별도로 확인해야 합니다.",
    "",
    "공식 확인 링크:",
    `- 인명용 한자 조회: ${OFFICIAL_EFAMILY_HANJA_URL}`,
    `- 자녀 이름 법령 안내: ${OFFICIAL_EASYLAW_NAME_URL}`,
    "",
  );

  return lines.join("\n");
}

export function downloadNamingMarkdown(input: NamingExportInput): void {
  const markdown = buildNamingMarkdown(input);
  const blob = new Blob([markdown], { type: "text/markdown;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `naming-report-${safeFilenamePart(input.result.name)}.md`;
  a.click();
  URL.revokeObjectURL(url);
}
