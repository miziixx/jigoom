import { describe, expect, it } from "vitest";
import { computeSajuChart } from "./saju.js";
import { compareNames } from "./naming.js";
import { buildNamingMarkdown } from "./exportNaming.js";
import type { BirthInfo } from "../types/index.js";

describe("이름 감정 저장", () => {
  it("후보 비교와 AI 해석을 마크다운에 포함한다", () => {
    const birth: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
    const comparison = compareNames(computeSajuChart(birth), [{ name: "김민준" }, { name: "이서아" }], "given-name", {
      mode: "brand",
      desiredImage: "고급스러움",
      purposeNote: "브랜드명 후보",
    });
    const markdown = buildNamingMarkdown({
      result: comparison.recommended,
      comparison,
      interpretation: "# 한 줄 결론\n좋은 균형입니다.",
    });

    expect(markdown).toContain("# 이름 감정 리포트");
    expect(markdown).toContain("발음오행 기준: 이름 중심 기준");
    expect(markdown).toContain("작명 목적: 상호명·브랜드명");
    expect(markdown).toContain("원하는 이미지: 고급스러움");
    expect(markdown).toContain("## 후보 이름 비교");
    expect(markdown).toContain("## AI 이름 해석 리포트");
    expect(markdown).toContain("상표, 도메인, SNS 계정");
    expect(markdown).toContain("인명용 한자 조회");
    expect(markdown).toContain("efamily.scourt.go.kr");
    expect(markdown).toContain("easylaw.go.kr");
  });
});
