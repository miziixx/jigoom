import type { ReactNode } from "react";

export type TarotSuitKey = "major" | "wands" | "cups" | "swords" | "pentacles";

export function tarotSuitKeyOf(name: string, arcana: string): TarotSuitKey {
  if (arcana === "major") return "major";
  if (name.includes("Wands")) return "wands";
  if (name.includes("Cups")) return "cups";
  if (name.includes("Swords")) return "swords";
  return "pentacles";
}

const SUIT_TITLE: Record<TarotSuitKey, string> = {
  major: "MAJOR ARCANA",
  wands: "WANDS",
  cups: "CUPS",
  swords: "SWORDS",
  pentacles: "PENTACLES",
};

/** 카드 중앙 문양. 78장 개별 일러스트 대신 수트/아르카나 상징을 스타일라이즈드 스트로크로 그린다. */
const MOTIFS: Record<TarotSuitKey, ReactNode> = {
  major: (
    <>
      <path d="M50 48l4.6 9.4 10.4 1.5-7.5 7.3 1.8 10.3L50 71.6l-9.3 4.9 1.8-10.3-7.5-7.3 10.4-1.5z" />
      <path d="M50 40v-5M50 92v-5M28 66h-5M77 66h-5M34.4 50.4l-3.5-3.5M69.1 85.1l-3.5-3.5M65.6 50.4l3.5-3.5M30.9 85.1l3.5-3.5" opacity="0.55" />
    </>
  ),
  wands: (
    <>
      <path d="M50 44v46" />
      <path d="M50 50l-9 7M50 50l9 7M50 62l-7 5.5M50 62l7 5.5M50 74l-5 4M50 74l5 4" />
      <path d="M50 44c-3.6 3.4-3.6 6.6 0 9.6 3.6-3 3.6-6.2 0-9.6z" opacity="0.8" />
    </>
  ),
  cups: (
    <>
      <path d="M34 50h32v7a16 16 0 0 1-32 0z" />
      <path d="M39 55c3.6-2.8 7.4-2.8 11 0s7.4 2.8 11 0" opacity="0.6" />
      <path d="M50 74v11M39 89h22M44 85h12" />
      <path d="M42 44c1.4-2.6 3.4-4 6-4M58 44c-1.4-2.6-3.4-4-6-4" opacity="0.5" />
    </>
  ),
  swords: (
    <>
      <path d="M50 40v38" />
      <path d="M44.5 47L50 40l5.5 7" />
      <path d="M36 78h28" />
      <path d="M50 78v9" />
      <circle cx="50" cy="90.5" r="2.4" />
      <path d="M40 58c6.5 3 13.5 3 20 0" opacity="0.5" />
    </>
  ),
  pentacles: (
    <>
      <circle cx="50" cy="67" r="22" />
      <path d="M50 49.5l5 10.6 11.6 1.2-8.7 7.8 2.5 11.4L50 74.6l-10.4 5.9 2.5-11.4-8.7-7.8 11.6-1.2z" />
    </>
  ),
};

/** 영문 이름이 길면 두 줄로 나눈다 (예: "Knight of Pentacles"). */
function splitName(name: string): string[] {
  if (name.length <= 13) return [name];
  const words = name.split(" ");
  let best = 1;
  let bestDiff = Infinity;
  for (let i = 1; i < words.length; i += 1) {
    const a = words.slice(0, i).join(" ").length;
    const b = words.slice(i).join(" ").length;
    const diff = Math.abs(a - b);
    if (diff < bestDiff) {
      bestDiff = diff;
      best = i;
    }
  }
  return [words.slice(0, best).join(" "), words.slice(best).join(" ")];
}

/**
 * 제네릭 스타일라이즈드 타로 카드 아트 (이중 프레임 + 수트 배너 + 중앙 문양 + 이름 카르투슈).
 * 역방향 회전은 기존 .tarot-card-visual--reversed 래퍼가 담당하므로 여기서는 그리지 않는다.
 */
export default function TarotCardArt({ name, arcana, koName }: { name: string; arcana: string; koName?: string | null }) {
  const suit = tarotSuitKeyOf(name, arcana);
  const en = name.split(" (")[0];
  const lines = splitName(en);

  return (
    <svg className={`tarot-card-art tarot-card-art--${suit}`} viewBox="0 0 100 150" role="img" aria-label={name}>
      <rect className="tarot-card-art__frame" x="4" y="4" width="92" height="142" rx="6" />
      <rect className="tarot-card-art__frame tarot-card-art__frame--dashed" x="9" y="9" width="82" height="132" rx="4" />
      {[
        [14, 14],
        [86, 14],
        [14, 136],
        [86, 136],
      ].map(([x, y]) => (
        <circle key={`${x}-${y}`} className="tarot-card-art__corner-dot" cx={x} cy={y} r="1.5" />
      ))}

      <text className="tarot-card-art__suit" x="50" y="23">
        {SUIT_TITLE[suit]}
      </text>
      <path className="tarot-card-art__rule" d="M22 28.5h56" />

      <g className="tarot-card-art__motif">{MOTIFS[suit]}</g>

      <path className="tarot-card-art__rule" d="M22 108h56" />
      {lines.map((line, i) => (
        <text key={line} className="tarot-card-art__name" x="50" y={lines.length === 1 ? 121 : 117 + i * 9}>
          {line}
        </text>
      ))}
      {koName && (
        <text className="tarot-card-art__ko" x="50" y="136">
          {koName}
        </text>
      )}
    </svg>
  );
}
