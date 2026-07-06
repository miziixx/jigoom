import { describe, expect, it } from "vitest";
import { goldenCases } from "./goldenCases.js";
import { checkGoldenCase, summarizeJudgmentPack, buildPackForCase } from "./goldenRunner.js";

/**
 * Golden 회귀 테스트 드라이버 (결정론·LLM 미호출).
 *
 * 실패 시: 실패한 케이스 id와 사유(누락 code / 도메인 부족 / confidence 이탈 / 허용 밖 모순 등)를 보고한다.
 * 의도적으로 엔진을 바꿔 기대값이 달라졌다면 goldenCases.ts를 리뷰 후 갱신한다(README 참조).
 */

describe("Golden Test Cases — 리딩 엔진 회귀", () => {
  it("케이스가 20개 이상이다", () => {
    expect(goldenCases.length).toBeGreaterThanOrEqual(20);
  });

  it("케이스 id는 유일하다", () => {
    const ids = goldenCases.map((c) => c.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it.each(goldenCases.map((c) => [c.id, c] as const))("%s: 회귀 기준 통과", (_id, def) => {
    const result = checkGoldenCase(def);
    // 실패 사유를 그대로 노출해 회귀 원인을 바로 알 수 있게 한다
    expect(result.failures, `${def.id}\n${result.failures.join("\n")}`).toEqual([]);
    expect(result.ok).toBe(true);
  });

  it("모든 케이스가 구조적으로 유효한 pack을 생성한다", () => {
    for (const def of goldenCases) {
      const summary = summarizeJudgmentPack(buildPackForCase(def.input));
      expect(summary.packGenerated, def.id).toBe(true);
      expect(summary.structurallyValid, `${def.id} issues=${summary.validationIssueCodes.join(",")}`).toBe(true);
    }
  });

  it("결정론: 같은 입력은 같은 요약을 낸다", () => {
    const def = goldenCases[0];
    const a = summarizeJudgmentPack(buildPackForCase(def.input));
    const b = summarizeJudgmentPack(buildPackForCase(def.input));
    expect(a).toEqual(b);
  });

  // 네거티브 컨트롤: 회귀 검사가 실제로 위반을 잡아내는지(=검사가 공허하지 않은지) 증명한다.
  describe("네거티브 컨트롤 — 위반이 실제로 감지된다", () => {
    const good = goldenCases[1]; // g02: money risk, startup notrec, 1 contradiction

    it("존재하지 않는 필수 code를 넣으면 실패한다", () => {
      const r = checkGoldenCase({ ...good, expect: { requiredJudgmentCodes: ["LOVE_STABLE"] } });
      expect(r.ok).toBe(false);
      expect(r.failures.some((f) => f.includes("LOVE_STABLE"))).toBe(true);
    });

    it("실제로 나오는 code를 금지하면 실패한다", () => {
      const r = checkGoldenCase({ ...good, expect: { forbiddenJudgmentCodes: ["CAREER_CHANGE_HIGH"] } });
      expect(r.ok).toBe(false);
    });

    it("도메인 커버리지 하한을 과하게 높이면 실패한다", () => {
      const r = checkGoldenCase({ ...good, expect: { minDomainCoverage: 99 } });
      expect(r.ok).toBe(false);
    });

    it("confidence 밴드를 불가능하게 좁히면 실패한다", () => {
      const r = checkGoldenCase({ ...good, expect: { overallConfidence: { min: 99, max: 100 } } });
      expect(r.ok).toBe(false);
    });

    it("contradiction 상한을 0으로 두면(실제 1건) 실패한다", () => {
      const r = checkGoldenCase({ ...good, expect: { allowedContradictionIds: [], maxContradictions: 0 } });
      expect(r.ok).toBe(false);
    });

    it("없는 evidence id를 필수로 요구하면 실패한다", () => {
      const r = checkGoldenCase({ ...good, expect: { requiredEvidenceIds: ["chart.does.not.exist"] } });
      expect(r.ok).toBe(false);
    });
  });
});
