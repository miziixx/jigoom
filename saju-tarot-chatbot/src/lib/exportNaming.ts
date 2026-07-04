import type { NameComparison, NameEvaluation } from "./naming";

interface NamingExportInput {
  result: NameEvaluation;
  comparison?: NameComparison | null;
  interpretation?: string | null;
}

function safeFilenamePart(value: string): string {
  return value.trim().replace(/[\\/:*?"<>|]+/g, "-").replace(/\s+/g, "-") || "name";
}

export function buildNamingMarkdown({ result, comparison, interpretation }: NamingExportInput): string {
  const lines: string[] = [
    "# 이름 감정 리포트",
    "",
    `- 이름: ${result.name}`,
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
