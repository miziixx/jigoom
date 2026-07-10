import { describe, expect, it } from "vitest";
import { astro } from "iztro";
import { allZiweiCombos, comboKey, lookupZiweiCombo, ZIWEI_MAJOR_STARS } from "./ziweiCombos.js";

/**
 * 자미두수 동궁 조합 KB 완결성 audit (엔진 업그레이드 Z-3, johuClassicAudit 패턴).
 *
 * 목적: KB의 모든 엔트리가 iztro가 실제로 만들어내는 조합이고, iztro가 만드는 모든 조합이 KB에
 * 있는지(누락 없음) 검증한다. 자미두수 14주성은 고정 배열 규칙이라 실존 조합 집합이 유한·불변이다.
 */

/** iztro 전수 스캔으로 실제 발생하는 (단성/동궁) 조합 키 집합을 만든다. */
function collectRealCombos(): Set<string> {
  const keys = new Set<string>();
  for (let y = 1960; y <= 2010; y += 2) {
    for (let mo = 1; mo <= 12; mo += 2) {
      for (let ti = 0; ti < 12; ti += 2) {
        try {
          const chart = astro.bySolar(`${y}-${String(mo).padStart(2, "0")}-15`, ti, "男", true, "ko-KR");
          for (const p of chart.palaces) {
            const majors = p.majorStars.map((s) => s.name).filter(Boolean);
            if (majors.length >= 1 && majors.length <= 2) keys.add(comboKey(majors));
          }
        } catch {
          // 잘못된 조합 스킵
        }
      }
    }
  }
  return keys;
}

describe("자미두수 동궁 조합 KB 완결성", () => {
  const real = collectRealCombos();

  it("KB의 모든 엔트리는 iztro가 실제로 만드는 조합이다 (허수 없음)", () => {
    for (const entry of allZiweiCombos()) {
      const key = comboKey(entry.stars);
      expect(real.has(key), `KB에 있으나 실존하지 않는 조합: ${key}`).toBe(true);
    }
  });

  it("iztro가 만드는 모든 단성·동궁 조합이 KB에 있다 (누락 없음)", () => {
    for (const key of real) {
      expect(lookupZiweiCombo(key.split("+")), `iztro 조합인데 KB 누락: ${key}`).not.toBeNull();
    }
  });

  it("모든 엔트리의 별은 14 주성에 속하고 gloss가 비어 있지 않다", () => {
    const valid = new Set(ZIWEI_MAJOR_STARS);
    for (const entry of allZiweiCombos()) {
      for (const star of entry.stars) expect(valid.has(star as (typeof ZIWEI_MAJOR_STARS)[number])).toBe(true);
      expect(entry.gloss.length).toBeGreaterThan(8);
    }
  });

  it("엔트리 키는 중복이 없다", () => {
    const keys = allZiweiCombos().map((e) => comboKey(e.stars));
    expect(new Set(keys).size).toBe(keys.length);
  });

  it("단성 14 + 동궁 24 = 38 엔트리", () => {
    const singles = allZiweiCombos().filter((e) => e.stars.length === 1);
    const pairs = allZiweiCombos().filter((e) => e.stars.length === 2);
    expect(singles.length).toBe(14);
    expect(pairs.length).toBe(24);
  });

  it("lookupZiweiCombo는 별 순서에 무관하게 조회된다", () => {
    const a = lookupZiweiCombo(["자미", "천부"]);
    const b = lookupZiweiCombo(["천부", "자미"]);
    expect(a).not.toBeNull();
    expect(a).toEqual(b);
  });
});
