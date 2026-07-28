import type { FortuneContent, FortuneEvidence } from "../types/index.js";

/**
 * 오늘의 운세 문장 생성용 시스템 프롬프트.
 * 핵심 아키텍처 원칙: 사주 계산(간지/십성/합충/신살)은 결정론적 엔진(lib/fortune.ts)이
 * 담당하고, LLM은 전달된 [근거 데이터]를 문장으로 옮기기만 한다. LLM은 계산하지 않는다.
 */
export const FORTUNE_SYSTEM_PROMPT = `너는 사주 기반 오늘의 운세를 작성하는 한국어 콘텐츠 엔진이다.
제공된 [근거 데이터]만 사용해서 문장을 작성한다. 간지, 십성, 합충을 새로 계산하거나
추측하지 않는다. 근거에 없는 내용은 쓰지 않는다.

[핵심 규칙]
1. 미래를 단정하지 않고 경향성과 "잘 맞는 행동/부딪히기 쉬운 패턴"으로 표현한다.
2. 건강/법률/투자/결혼/이직 같은 중대 결정을 운세로 대신 내려주지 않는다.
3. 공포형·저주형·운명 확정형 표현("반드시", "무조건", "헤어져야 한다")을 금지한다.
4. 근거 데이터의 십성/합충/신살을 최소 3회 이상 자연스럽게 문장에 녹인다.
   (예: 충이 있으면 "일정 변동이 생기기 쉬운 날" 식으로 번역)
5. "이렇게 읽어볼 수 있어요", "오늘 체크할 포인트는" 같은 완곡하고 현실적인 문체를 쓴다.

[출력 형식 - JSON으로만 응답]
{
  "summary": "한 줄 총평",
  "keywords": ["키워드1", "키워드2", "키워드3"],
  "good_areas": ["잘 풀리는 영역 2~3개"],
  "caution_points": ["주의 포인트 2~3개"],
  "do_actions": ["추천 행동 3개"],
  "avoid_actions": ["피할 행동 2개"],
  "categories": {
    "love": "한 줄", "work": "한 줄", "money": "한 줄",
    "relationship": "한 줄", "condition": "한 줄"
  },
  "share_text": "친구에게 보내도 자연스러운 3~5줄 복붙용 버전"
}

출력 전 자체 점검: 단정형 문장, 공포 조장, 중대 결정 유도, 근거 미반영,
뭉뚱그린 일반론이 있으면 수정 후 출력한다.

응답은 위 JSON 객체 하나로만 한다. 코드블록(\`\`\`)이나 설명 문장을 앞뒤에 붙이지 않는다.`;

// ── 근거 데이터 직렬화 ──────────────────────────────────────────

function formatRelations(evidence: FortuneEvidence): string {
  const active = evidence.branchRelations.filter((r) => r.relations.length > 0);
  if (active.length === 0) return "  - 오늘 지지와 뚜렷한 합충 관계 없음 (원국을 크게 흔들지 않는 무난한 날)";
  return active
    .map((r) => `  - ${r.position} ${r.myBranch} ↔ 오늘 ${r.todayBranch}: ${r.relations.join("·")}${r.position === "일지" ? " (일지 = 나·일상·배우자 자리, 영향 큼)" : ""}`)
    .join("\n");
}

/** 결정론적 근거 데이터를 LLM이 읽을 [근거 데이터] 텍스트로 직렬화한다. */
export function buildFortuneUserMessage(evidence: FortuneEvidence): string {
  const e = evidence;
  const n = e.natal;
  const c = e.categories;
  const lucky = e.luckyItems;

  const lines: string[] = [
    "[근거 데이터]",
    `기준 날짜: ${e.date} (${e.weekday}요일, Asia/Seoul)`,
    `오늘 간지 — 일진 ${e.ganzhi.day} / 이번 달 월운 ${e.ganzhi.month} / 올해 세운 ${e.ganzhi.year}`,
    "",
    `내 원국 — 일간 ${n.dayMaster}(${n.dayMasterElement}) · 신강신약 ${n.strength} · 용신 후보 ${n.yongshin.join("·") || "없음"}${n.gishin.length ? ` · 기신 후보 ${n.gishin.join("·")}` : ""}${n.hasHour ? "" : " (출생시간 모름 → 시주 제외)"}`,
    `연주 ${n.pillars.year} / 월주 ${n.pillars.month} / 일주 ${n.pillars.day}${n.pillars.hour ? ` / 시주 ${n.pillars.hour}` : ""}`,
    "",
    `십성(내 일간 → 오늘 일진 천간): ${e.tenGod.name} [${e.tenGod.group}]`,
    `  → ${e.tenGod.axis}`,
    "",
    "지지 관계(내 지지 ↔ 오늘 지지):",
    formatRelations(e),
    "",
    `오행 조력도: ${e.elementSupport.score > 0 ? "+" : ""}${e.elementSupport.score} / 100 — ${e.elementSupport.detail}`,
    `12운성(오늘 지지에서 내 일간의 기운): ${e.twelveStage.stage} (에너지 ${e.twelveStage.energyLevel}/100)`,
    `신살: ${e.sinsal.hits.length ? e.sinsal.hits.join(", ") : "오늘 해당 신살 없음"}`,
    "",
    "카테고리 점수(0~100, 높을수록 순조):",
    `  총운 ${c.overall} / 재물 ${c.money} / 애정 ${c.love} / 직장·학업 ${c.career} / 건강 ${c.health} / 대인관계 ${c.relationship}`,
    "",
    `행운 아이템: 오행 ${lucky.element} · 색 ${lucky.colors.join("·")} · 방위 ${lucky.direction} · 숫자 ${lucky.numbers.join("·")} · 시간대 ${lucky.timeSlot.zhi}시(${lucky.timeSlot.range})`,
    "",
    "위 [근거 데이터]만 사용해서, 시스템 프롬프트의 JSON 출력 형식에 정확히 맞춰 오늘의 운세를 작성해줘.",
    "categories의 각 항목(love/work/money/relationship/condition)은 위 카테고리 점수의 높낮이와 근거(십성·합충·신살)를 반영해서 한 줄씩 쓴다.",
  ];

  return lines.join("\n");
}

// ── 모델 응답 파싱 ──────────────────────────────────────────────

function isStringArray(v: unknown): v is string[] {
  return Array.isArray(v) && v.every((x) => typeof x === "string");
}

/**
 * 모델 출력 텍스트에서 FortuneContent JSON을 견고하게 추출·검증한다.
 * 코드블록 펜스나 앞뒤 잡텍스트가 있어도 첫 `{`~마지막 `}` 구간을 파싱한다.
 * 형식이 어긋나면 null을 반환한다 (호출부가 폴백을 쓰도록).
 */
export function parseFortuneContent(text: string): FortuneContent | null {
  const stripped = text
    .trim()
    .replace(/^```(?:json)?/i, "")
    .replace(/```$/i, "")
    .trim();
  const start = stripped.indexOf("{");
  const end = stripped.lastIndexOf("}");
  if (start < 0 || end <= start) return null;

  let obj: unknown;
  try {
    obj = JSON.parse(stripped.slice(start, end + 1));
  } catch {
    return null;
  }
  if (typeof obj !== "object" || obj === null) return null;
  const o = obj as Record<string, unknown>;
  const cats = o.categories as Record<string, unknown> | undefined;

  if (
    typeof o.summary !== "string" ||
    !isStringArray(o.keywords) ||
    !isStringArray(o.good_areas) ||
    !isStringArray(o.caution_points) ||
    !isStringArray(o.do_actions) ||
    !isStringArray(o.avoid_actions) ||
    typeof o.share_text !== "string" ||
    !cats ||
    typeof cats.love !== "string" ||
    typeof cats.work !== "string" ||
    typeof cats.money !== "string" ||
    typeof cats.relationship !== "string" ||
    typeof cats.condition !== "string"
  ) {
    return null;
  }

  return {
    summary: o.summary,
    keywords: o.keywords,
    good_areas: o.good_areas,
    caution_points: o.caution_points,
    do_actions: o.do_actions,
    avoid_actions: o.avoid_actions,
    categories: {
      love: cats.love,
      work: cats.work,
      money: cats.money,
      relationship: cats.relationship,
      condition: cats.condition,
    },
    share_text: o.share_text,
  };
}
