import { describe, expect, it } from "vitest";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

/**
 * 서버리스 함수(api/*.ts)가 도달하는 모든 파일의 상대 import에 .js 확장자가 있는지 검사한다.
 *
 * 배경: Vite(브라우저 번들)와 vitest는 확장자 없는 상대 import("../data/tarotDeck")를 해석해주지만,
 * Vercel의 Node ESM 런타임은 확장자가 없으면 ERR_MODULE_NOT_FOUND로 함수 자체가 뜨자마자 죽는다.
 * 실제로 타로 데이터 파일 import 3곳이 확장자 없이 들어가 /api/reading 전체가 500
 * ("A server error occurred")으로 죽는 프로덕션 장애가 있었다(2026-07-11, docs/record.md 참고).
 * 로컬 테스트·빌드는 전부 통과해서 이 테스트 없이는 배포 전에 잡을 방법이 없다.
 *
 * 규칙: api/*.ts에서 시작해 상대 import 그래프를 걸으며, 런타임(값) import는 반드시
 * .js(또는 .json/.mjs/.cjs) 확장자를 붙여야 한다. `import type { ... }`(pure type)은
 * 컴파일 시 지워지므로 확장자가 없어도 된다.
 */

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

const STATIC_IMPORT_RE = /(import|export)\s+([\s\S]*?)\s+from\s+["']([^"']+)["']/g;
const SIDE_EFFECT_IMPORT_RE = /(?<![\w.])import\s+["']([^"']+)["']/g;
const HAS_EXT_RE = /\.(js|json|mjs|cjs)$/;

function resolveToSource(fromFile: string, spec: string): string | null {
  const base = path.resolve(path.dirname(fromFile), spec.replace(/\.js$/, ""));
  for (const cand of [`${base}.ts`, `${base}.tsx`, path.join(base, "index.ts")]) {
    if (fs.existsSync(cand)) return cand;
  }
  return null;
}

function collectViolations(): { walked: number; violations: string[] } {
  const apiDir = path.join(ROOT, "api");
  const queue = fs
    .readdirSync(apiDir)
    .filter((f) => f.endsWith(".ts") && !f.endsWith(".test.ts"))
    .map((f) => path.join(apiDir, f));

  const seen = new Set<string>();
  const violations: string[] = [];

  while (queue.length > 0) {
    const file = queue.pop()!;
    if (seen.has(file)) continue;
    seen.add(file);
    const text = fs.readFileSync(file, "utf8");

    for (const m of text.matchAll(STATIC_IMPORT_RE)) {
      const [, , clause, spec] = m;
      if (!spec.startsWith(".")) continue;
      const pureType = /^type[\s{]/.test(clause.trim());
      if (!pureType && !HAS_EXT_RE.test(spec)) {
        const line = text.slice(0, m.index).split("\n").length;
        violations.push(`${path.relative(ROOT, file)}:${line} → "${spec}" (확장자 .js 필요)`);
      }
      if (!pureType) {
        const next = resolveToSource(file, spec);
        if (next) queue.push(next);
      }
    }
    for (const m of text.matchAll(SIDE_EFFECT_IMPORT_RE)) {
      const spec = m[1];
      if (!spec.startsWith(".")) continue;
      if (!HAS_EXT_RE.test(spec)) {
        const line = text.slice(0, m.index).split("\n").length;
        violations.push(`${path.relative(ROOT, file)}:${line} → "${spec}" (확장자 .js 필요)`);
      }
      const next = resolveToSource(file, spec);
      if (next) queue.push(next);
    }
  }

  return { walked: seen.size, violations };
}

describe("서버리스 함수 ESM import 규칙 — 상대 import는 .js 확장자 필수", () => {
  it("api/*.ts가 도달하는 모든 파일에 확장자 없는 런타임 상대 import가 없다", () => {
    const { walked, violations } = collectViolations();
    // 그래프가 실제로 걸렸는지 방어 (0이면 검사 자체가 깨진 것)
    expect(walked).toBeGreaterThan(10);
    expect(violations, `Vercel Node ESM에서 ERR_MODULE_NOT_FOUND로 함수가 죽는 import:\n${violations.join("\n")}`).toEqual([]);
  });
});
